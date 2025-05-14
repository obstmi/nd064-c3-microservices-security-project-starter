# #!/bin/bash
# #start monero_cpu_moneropool
# kubectl run --kubeconfig kube_config_cluster.yml moneropool --image=servethehome/monero_cpu_moneropool:latest --replicas=1
# #start minergate
# kubectl run --kubeconfig kube_config_cluster.yml minergate --image=servethehome/monero_cpu_minergate:latest --replicas=1
# #start cryptotonight
# kubectl run --kubeconfig kube_config_cluster.yml cryptotonight --image=servethehome/universal_cryptonight:latest --replicas=1

# echo "Can you identify the payload(s)?"

#!/bin/bash
# Start monero_cpu_moneropool
kubectl create deployment moneropool --kubeconfig kube_config_cluster.yml --image=servethehome/monero_cpu_moneropool:latest
kubectl scale deployment moneropool --kubeconfig kube_config_cluster.yml --replicas=1

# Start minergate
kubectl create deployment minergate --kubeconfig kube_config_cluster.yml --image=servethehome/monero_cpu_minergate:latest
kubectl scale deployment minergate --kubeconfig kube_config_cluster.yml --replicas=1

# Start cryptotonight
kubectl create deployment cryptotonight --kubeconfig kube_config_cluster.yml --image=servethehome/universal_cryptonight:latest
kubectl scale deployment cryptotonight --kubeconfig kube_config_cluster.yml --replicas=1

echo "Deployments created and scaled."