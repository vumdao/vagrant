<p align="center">
  <a href="https://dev.to/vumdao">
    <img alt="Launch a multi-node cluster using Vagrant and KVM" src="https://github.com/vumdao/vagrant/blob/master/kube/cover.png?raw=true" width="500" />
  </a>
</p>
<h1 align="center">
  <div><b>Launch a multi-node cluster using Vagrant and KVM</b></div>
</h1>

---

## What’s In This Document 
- [Create Vagrantfile](#-Create-Vagrantfile)
- [Bootstrap script for master and worker nodes](#-Bootstrap-script-for-master-and-worker-nodes)
- [Bootstrap a Kubernetes cluster using Kubeadm](#-Bootstrap-a-Kubernetes-cluster-using-Kubeadm)
- [Join nodes to Kubernetes cluster](#-Join-nodes-to-Kubernetes-cluster)
- [Vagrant up and check result](#-Vagrant-up-and-check-result)

---

### 🚀 **[Create Vagrantfile](#-Create-Vagrantfile)**

**Following is to create 1 master + 2 slaves (libvirt driver KVM)**
```
# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.provider :libvirt do |libvirt|
        libvirt.driver = "kvm"
    end
    config.vm.synced_folder './shared', '/vagrant', type: '9p', disabled: false, accessmode: "mapped"
    config.vm.box = "generic/ubuntu2004"
    config.vm.box_version = "3.0.6"
    config.vm.network "forwarded_port", guest: 5432, host: 5432
    config.vm.provision:shell, inline: <<-SHELL
        echo "root:rootroot" | sudo chpasswd
        sudo timedatectl set-timezone Asia/Ho_Chi_Minh
    SHELL

    config.vm.define "kube1" do |kube1|
        kube1.vm.hostname = "kube1"
        kube1.vm.network "private_network", ip: "192.168.121.211"
        kube1.vm.provision:shell, inline: <<-SHELL
            sudo echo -e "192.168.121.211\tkube1" >> /etc/hosts
        SHELL
        kube1.vm.provision:shell, path: "kube-bootstrap.sh"
    end

    config.vm.define "kube2" do |kube2|
        kube2.vm.hostname = "kube2"
        kube2.vm.network "private_network", ip: "192.168.121.212"
        kube2.vm.provision:shell, inline: <<-SHELL
            sudo echo -e "192.168.121.212\tkube2" >> /etc/hosts
        SHELL
        kube2.vm.provision:shell, path: "kube-bootstrap.sh"
    end

    config.vm.define "master" do |master|
        master.vm.hostname = "master"
        master.vm.network "private_network", ip: "192.168.121.210"
        master.vm.provision:shell, inline: <<-SHELL
            sudo sed -i 's/127\.0\.1\.1.*master//' /etc/hosts
            sudo echo -e "192.168.121.210\tmaster" >> /etc/hosts
        SHELL
        master.vm.provision:shell, path: "kube-bootstrap.sh"
        master.vm.provision:shell, path: "kubeadm_reinstall.sh"
    end
end
```

- You can configure as many masters and slaves as you like. 
```
# master
kube1.vm.network "private_network", ip: "192.168.121.210"

# kube1
kube1.vm.network "private_network", ip: "192.168.121.211"

# kube2
kube2.vm.network "private_network", ip: "192.168.121.212"
```

### 🚀 **[Bootstrap script for master and worker nodes](#-Bootstrap-script-for-master-and-worker-nodes)**
```
#!/bin/bash
# Bootstrap machine

ensure_netplan_apply() {
    # First node up assign dhcp IP for eth1, not base on netplan yml
    sleep 5
    sudo netplan apply
}

step=1
step() {
    echo "Step $step $1"
    step=$((step+1))
}

resolve_dns() {
    step "===== Create symlink to /run/systemd/resolve/resolv.conf ====="
    sudo rm /etc/resolv.conf
    sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
}

install_docker() {
    step "===== Installing docker ====="
    sudo apt update
    sudo apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    sudo groupadd docker
    sudo gpasswd -a $USER docker
    sudo chmod 777 /var/run/docker.sock
}

install_kube() {
    step "===== Installing kube ====="
    sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
    sudo apt update
    sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
    sudo apt install -y kubeadm
    sudo swapoff -a
    sudo echo "source <(kubectl completion bash)" >> /home/vagrant/.bashrc
    sudo echo "source <(kubeadm completion bash)" >> /home/vagrant/.bashrc
}

setup_root_login() {
    step "===== Setup root login ====="
    sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sudo systemctl restart ssh
    sudo echo "root:rootroot" | chpasswd
}

setup_welcome_msg() {
    step "===== Bash ====="
    sudo apt -y install cowsay
    sudo echo -e "\necho \"Welcome to Vagrant Kube Ubuntu 18.04\" | cowsay\n" >> /home/vagrant/.bashrc
    sudo ln -s /usr/games/cowsay /usr/local/bin/cowsay
    sudo apt install -y tcl expect net-tools
}

main() {
    ensure_netplan_apply
    resolve_dns
    install_docker
    install_kube
    setup_root_login
    setup_welcome_msg
}

main
```

### 🚀 **[Bootstrap a Kubernetes cluster using Kubeadm](#-Bootstrap-a-Kubernetes-cluster-using-Kubeadm)**
```
#!/bin/bash
# Reset and start kubeadm

echo "Enter password:"
read -s PASSWORD

sudo_expect() {
    command="sudo $1"
    cat > /tmp/tmp.exp <<EOF
#!/usr/bin/expect
set password [lindex \$argv 0]
set cmd [lrange \$argv 1 end]

spawn {*}\$cmd

expect {
    "password" {
        send "\$password\r"
        exp_continue
    }
    "Are you sure you want to proceed?" {
        send "y\r"
        exp_continue
    }
    eof {
        exit
    }
}

interact
EOF

    expect /tmp/tmp.exp $PASSWORD $command
}

resestKubeadm() {
    sudo_expect "kubeadm reset -f"
    sudo_expect "iptables -F"
}

initKubeadm() {
    sudo_expect "swapoff -a"
    if [ "$(hostname)" != "master" ]; then
        sudo_expect "hostname master"
    fi
    sudo_expect "rm -rf /var/lib/etcd/member"
    sudo_expect "kubeadm init --node-name master --apiserver-advertise-address $(hostname -i)"
    mkdir -p $HOME/.kube
    rm -f $HOME/.kube/config
    sudo_expect "cp -i /etc/kubernetes/admin.conf $HOME/.kube/config"
    sudo_expect "chown $(id -u):$(id -g) $HOME/.kube/config"
    sudo_expect "chmod +wr /etc/kubernetes/admin.conf"
}

kubeAddOn() {
    kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
}

resestKubeadm
initKubeadm
kubeAddOn
```

### 🚀 **[Join nodes to Kubernetes cluster](#-Join-nodes-to-Kubernetes-cluster)**
```
#!/bin/bash
# Join remote node to kubernetes cluster

ip=$1
PASSWORD="rootroot"

ssh_expect() {
    command="$1"
    cat > /tmp/tmp.exp <<EOF
#!/usr/bin/expect
set password [lindex \$argv 0]
set cmd [lrange \$argv 1 end]

spawn {*}\$cmd

expect {
    "password" {
        send "\$password\r"
        exp_continue
    }
    "Are you sure you want to proceed?" {
        send "y\r"
        exp_continue
    }
    eof {
        exit
    }
}

interact
EOF

    expect /tmp/tmp.exp $PASSWORD $command
}

# Get token-ca-cert-hash
sha=$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \
        openssl dgst -sha256 -hex | sed 's/^.* //')

# Get token of master node by creating new one
token=$(kubeadm token create)

# Join the remote node
cluster_ip=$(kubectl get node master -o jsonpath="{.status.addresses[0].address}")
ssh_expect "ssh root@$ip kubeadm reset"
ssh_expect "ssh root@$ip swapoff -a"
ssh_expect "ssh root@$ip kubeadm join ${cluster_ip}:6443 --token ${token} --discovery-token-ca-cert-hash sha256:${sha}"
```

### 🚀 **[Vagrant up and check result](#-Vagrant-up-and-check-result)**
- UP
```
vagrant up
```

- Get nodes
```
vagrant@master:/vagrant$ kubectl get node
NAME     STATUS   ROLES                  AGE    VERSION
kube1    Ready    <none>                 2d1h   v1.21.0
kube2    Ready    <none>                 2d1h   v1.21.0
master   Ready    control-plane,master   2d1h   v1.21.0
```

- KVM

![Alt-Text](https://github.com/vumdao/vagrant/blob/master/kube/k8s_cluster.png?raw=true)

---

<h3 align="center">
  <a href="https://dev.to/vumdao">:stars: Blog</a>
  <span> · </span>
  <a href="https://github.com/vumdao/">Github</a>
  <span> · </span>
  <a href="https://stackoverflow.com/users/11430272/vumdao">Web</a>
  <span> · </span>
  <a href="https://www.linkedin.com/in/vu-dao-9280ab43/">Linkedin</a>
  <span> · </span>
  <a href="https://www.linkedin.com/groups/12488649/">Group</a>
  <span> · </span>
  <a href="https://www.facebook.com/CloudOpz-104917804863956">Page</a>
  <span> · </span>
  <a href="https://twitter.com/VuDao81124667">Twitter :stars:</a>
</h3>