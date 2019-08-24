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
