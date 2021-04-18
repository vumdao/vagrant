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

setup_nfs() {
    step "===== Installing nfs-server in case of testing NFS ====="
    sudo apt install -y nfs-kernel-server
}

setup_root_login() {
    step "===== Setup root login ====="
    sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sudo systemctl restart ssh
    sudo echo "root:rootroot" | chpasswd
    sudo echo "vagrant:rootroot" | chpasswd
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
