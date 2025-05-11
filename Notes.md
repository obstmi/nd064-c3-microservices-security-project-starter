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



## Tips
* We can access a running Docker container using `kubectl exec -it <pod_id> sh`. From there, we can `curl` an endpoint to debug network issues.
* The starter project uses Python Flask. Flask doesn't work well with `asyncio` out-of-the-box. Consider using `multiprocessing` to create threads for asynchronous behavior in a standard Flask application.
* Create a virtual Python environment  
python3 -m venv .myvenv  
source .myvenv/bin/activate  
..  
deactivate
* Docker compose up and down:  
docker compose down  
docker compose build  
docker compose up  
* Harden docker environment:  
docker pull opensuse/leap:latest
docker build . -t obstmi/leap:hardened-v0.1 -m 256mb --no-cache=true  

