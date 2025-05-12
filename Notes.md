# Installations  
## docker bench
* git clone https://github.com/aquasecurity/docker-bench.git
* cd docker-bench 
* go build -o docker-bench 
* ./docker-bench --help 
* ./docker-bench --include-test-output --benchmark cis-1.2 > docker-bench.txt
* cat docker-bench.txt | grep FAIL


## Grype (local)
* mkdir -p $HOME/.local/bin
* curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b $HOME/.local/bin
* export PATH="$HOME/.local/bin:$PATH"

## Deploy the RKE cluster
* vagrant up
* if necessary: delete obsolete entries in ~/.ssh/known_hosts
* ssh-copy-id -i ~/.ssh/id_rsa root@192.168.50.101  (on Mac: without sudo)
* test: ssh root@192.168.50.101
* cd ~/.local/bin
* curl -LO https://github.com/rancher/rke/releases/download/v1.2.6/rke_darwin-amd64
* mv rke_darwin-amd64 rke
* chmod +x rke
* test: rke --version
* cd [project-folder]
* rke up --ignore-docker-version
* verify: kubectl --kubeconfig kube_config_cluster.yml get nodes
* verify: kubectl --kubeconfig kube_config_cluster.yml get pods -A

## Running Kube-bench to Evaluate Rancher RKE
* ssh root@192.168.50.101
### on Node1: 
* docker run --pid=host -v /etc:/node/etc:ro -v /var:/node/var:ro -ti rancher/security-scan:v0.2.2 bash
### on rancher/security-scan:
* kube-bench run --targets etcd,master,controlplane,policies --scored --config-dir=/etc/kube-bench/cfg --benchmark rke-cis-1.6-hardened  
* kube-bench run --targets etcd,master,controlplane,policies --scored --config-dir=/etc/kube-bench/cfg --benchmark rke-cis-1.6-hardened | grep FAIL  
* kube-bench run --targets etcd,master,controlplane,policies --scored --config-dir=/etc/kube-bench/cfg --benchmark rke-cis-1.6-permissive  

## Harden Rancher RKE via Baseline Hardening
### Configure the Etcd User and Group
* [FAIL] 1.1.12 Ensure that the etcd data directory ownership is set to etcd:etcd (Automated)
* groupadd --gid 52034 etcd
* useradd --comment "etcd service account" --uid 52034 --gid 52034 etcd
* chown etcd:etcd /var/lib/etcd
* Update the RKE config.yml with the uid and gid of the etcd user:  
```
services:
  etcd:
    gid: 52034
    uid: 52034
```
### Configure Kernel Runtime Parameters
* cd /etc/sysctl.d
* touch 90-kubelet.conf
* vi 90-kubelet.conf
```
vm.overcommit_memory=1
vm.panic_on_oom=0
kernel.panic=10
kernel.panic_on_oops=1
kernel.keys.root_maxbytes=25000000
```
* sysctl -p /etc/sysctl.d/90-kubelet.conf

### Update the current cluster.yml with hardening steps per Rancher's reference hardened cluster.yml:
* https://github.com/rancher/rancher-docs/blob/main/archived_docs/en/version-2.0-2.4/reference-guides/rancher-security/rancher-v2.4-hardening-guides/hardening-guide-with-cis-v1.5-benchmark.md

### Re-evaluate Rancher RKE
* rke up --ignore-docker-version
* ssh root@192.168.50.101
* docker run --pid=host -v /etc/passwd:/etc/passwd -v /etc/group:/etc/group -v /etc:/node/etc:ro -v /var:/node/var:ro -ti rancher/security-scan:v0.2.2 bash
* kube-bench run --targets etcd,master,controlplane,policies --scored --config-dir=/etc/kube-bench/cfg --benchmark rke-cis-1.6-hardened | grep FAIL  


## Tips
* We can access a running Docker container using `kubectl exec -it <pod_id> sh`. From there, we can `curl` an endpoint to debug network issues.
* The starter project uses Python Flask. Flask doesn't work well with `asyncio` out-of-the-box. Consider using `multiprocessing` to create threads for asynchronous behavior in a standard Flask application.
### Create a virtual Python environment  
* python3 -m venv .myvenv  
* source .myvenv/bin/activate  
* ..  
* deactivate
### Docker compose up and down:  
* docker compose down  
* docker compose build  
* docker compose up  
### Harden docker environment:  
* docker pull opensuse/leap:latest
* docker build . -t obstmi/leap:hardened-v0.1 -m 256mb --no-cache=true  
* docker run --memory=256m obstmi/leap:hardened-v0.1

