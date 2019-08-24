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
