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

## Implement Runtime Monitoring and Grafana
### Install Falco Drivers on the Node
* ssh root@192.168.50.101
* rpm --import https://falco.org/repo/falcosecurity-packages.asc
* curl -s -o /etc/zypp/repos.d/falcosecurity.repo https://falco.org/repo/falcosecurity-rpm.repo
* sudo zypper dist-upgrade
### Reboot and install kernel headers
* sudo reboot
* (after some minutes:) ssh root@192.168.50.101
* sudo zypper -n install dkms make
* sudo zypper -n install kernel-default-devel
* sudo zypper -n install dialog
### Install Falco on the Node
* sudo zypper -n install falco
* sudo systemctl status falco (## Verify the installation)
* if error: "Unit falco.service could not be found." 
* sudo systemctl enable falco-kmod.service
### Reload Systemd and Start the Service
* sudo systemctl daemon-reload
* sudo systemctl enable falco
* sudo systemctl start falco
### Install Falco as a Daemonset on RKE Cluster
### Install Helm on the Host:
* curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
* chmod 700 get_helm.sh
* sudo ./get_helm.sh  ---> helm installed into /usr/local/bin/helm!!!
* helm version
### Install Falco on the Master Node as a Daemonset
* helm repo add falcosecurity https://falcosecurity.github.io/charts
* helm repo update
* helm install --kubeconfig kube_config_cluster.yml falco falcosecurity/falco --namespace falco --create-namespace --set falco.grpc.enabled=true --set falco.grpc_output.enabled=true
* If needed, to uninstall a helm deployment, you can run:  
helm list --kubeconfig kube_config_cluster.yml --all --all-namespaces  
helm uninstall falco --kubeconfig kube_config_cluster.yml  --namespace falco  
### Check the Falco Daemonset health
* kubectl --kubeconfig kube_config_cluster.yml get namespace
* kubectl --kubeconfig kube_config_cluster.yml get pods --namespace falco
* kubectl --kubeconfig kube_config_cluster.yml get ds --namespace falco 
* kubectl --kubeconfig kube_config_cluster.yml get ds falco --namespace falco -o yaml | grep serviceAcc

### Troubleshooting:
* kubectl --kubeconfig kube_config_cluster.yml get events --namespace falco
* kubectl --kubeconfig kube_config_cluster.yml describe nodes
* kubectl --kubeconfig kube_config_cluster.yml describe node node1
* kubectl --kubeconfig kube_config_cluster.yml describe pod <pod-name> -n falco
* kubectl --kubeconfig kube_config_cluster.yml logs falco-4lflg -n falco -c falco-driver-loader
* Error Pod creation: "PodSecurityPolicy enabled" in cluster.yml:  
```
kube-api:
  pod_security_policy: true
```

### Monitor Runtime Events
* kubectl --kubeconfig kube_config_cluster.yml get pods --namespace falco
* kubectl --kubeconfig kube_config_cluster.yml exec --stdin -it falco-l2z52 --namespace falco -- /bin/bash
* export PS1='\e[0;31m\u@\h:\W> \e[m'
* cat /etc/falco/falco.yaml # ## View the falco.yaml file.
* kubectl --kubeconfig kube_config_cluster.yml logs falco-l2z52 --namespace falco
* kubectl --kubeconfig kube_config_cluster.yml logs falco-l2z52 --namespace falco | grep adduser
* kubectl --kubeconfig kube_config_cluster.yml logs falco-l2z52 --namespace falco | grep etc/shadow

### Deploy Kube-prometheus-stack
* kubectl apply --kubeconfig kube_config_cluster.yml  --validate=false -f https://github.com/cert-manager/cert-manager/releases/download/v1.3.1/cert-manager.yaml # Install the CustomResourceDefinition resources separately
* helm repo add jetstack https://charts.jetstack.io
* helm repo update
* helm install --kubeconfig kube_config_cluster.yml cert-manager jetstack/cert-manager  --namespace cert-manager --create-namespace --version v1.3.1
* helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
* helm repo add stable https://charts.helm.sh/stable
* helm repo update 
* helm install --kubeconfig kube_config_cluster.yml prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace --generate-name  --version 16.5.0
* helm list --kubeconfig kube_config_cluster.yml --all --all-namespaces
* kubectl --kubeconfig kube_config_cluster.yml get pods --namespace monitoring
* (in case of problems) helm uninstall kube-prometheus-stack-1747136684 --kubeconfig kube_config_cluster.yml --namespace monitoring
### Install Falco exporter
* helm repo update
* helm install --kubeconfig kube_config_cluster.yml falco-exporter --namespace falco --set serviceMonitor.enabled=true falcosecurity/falco-exporter
* helm list --kubeconfig kube_config_cluster.yml --all --all-namespaces
* kubectl --kubeconfig kube_config_cluster.yml get pods --namespace falco
* (in case of problems:)  
helm list --kubeconfig kube_config_cluster.yml --all --all-namespaces  
helm uninstall falco-exporter --kubeconfig kube_config_cluster.yml  --namespace falco
### Port-forward the falco-exporter
* export POD_NAME=$(kubectl --kubeconfig kube_config_cluster.yml get pods --namespace falco -l "app.kubernetes.io/name=falco-exporter,app.kubernetes.io/instance=falco-exporter" -o jsonpath="{.items[0].metadata.name}")
* echo $POD_NAME
* kubectl --kubeconfig kube_config_cluster.yml port-forward --namespace falco $POD_NAME 9376

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

