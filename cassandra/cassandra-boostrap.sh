#!/bin/bash
# Bootstrap machine

ensure_netplan_apply() {
    # First node up assign dhcp IP for eth1, not base on netplan yml
    sleep 5
    sudo netplan apply
}

ip="192.168.121.101"

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

install_cassandra() {
    step "===== Installing cassandra ====="

    sudo apt-get update
    sudo apt-get -y install
	sudo apt install openjdk-8-jdk -y
	echo  "JAVA_HOME=$(readlink -f /usr/bin/java | sed "s:bin/java::")" | sudo tee -a /etc/profilec
	sudo apt install python -y
	sudo apt install python-pip
	echo "deb http://www.apache.org/dist/cassandra/debian 311x main" | sudo tee -a /etc/apt/sources.list.d/cassandra.sources.list
	curl https://www.apache.org/dist/cassandra/KEYS | sudo apt-key add -
	sudo apt update
	sudo apt install cassandra -y
	sudo useradd cassandra
	sudo groupadd cassandra
	sudo usermod -aG cassandra cassandra
}

setup_welcome_msg() {
    sudo apt-get -y install cowsay
    sudo echo -e "\necho \"Welcome to Vagrant Cassandra	Ubuntu 18.04\" | cowsay\n" >> /home/vagrant/.bashrc
    sudo ln -s /usr/games/cowsay /usr/local/bin/cowsay
}

main() {
    ensure_netplan_apply
    resolve_dns
    install_cassandra
    setup_welcome_msg
}

main
