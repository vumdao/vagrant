# Kubernetes cluster with vagrant

> **1 master + 2 slaves**

You can configure as many masters and slaves as you like. 
````
# master
kube1.vm.network "private_network", ip: "192.168.121.210"

# kube1
kube1.vm.network "private_network", ip: "192.168.121.211"

# kube2
kube2.vm.network "private_network", ip: "192.168.121.212"
````

###How to run
```
vagrant up

# Run kubeadm_reinstall.sh on master node to init kubeadm

# Run `kubeadm_join.sh <kube_slave_ip>` to join the slave into kubernetes cluster 
```
