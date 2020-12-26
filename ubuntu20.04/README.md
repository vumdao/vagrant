![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/1mwcz5syepfz73elnvhl.png)
# Create An Ubuntu 20.04 Server Using Vagrant
- Ubuntu Server is familiar with most of developers to run test or try/quick-start new feature, tools, etc.

- Specific usecases are kubernetes (k8s) cluster, postgresql database servers with master and standby ones, try cassandra, etc.

- Using vagrant for quick start and this is how to setup basic Ubuntu server
![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/8rjbqdrutwsnjibkrinc.png)
### **1. Create [`Vagrantfile`](https://github.com/vumdao/vagrant/blob/master/ubuntu20.04/Vagrantfile) file**
- User ubuntu version 20.04
 - Checkout the box version in [generic/ubuntu2004](https://app.vagrantup.com/generic/boxes/ubuntu2004)
 - Box version needs to support `libvirt Hosted by Vagrant Cloud (1.4 GB)`
 - eg. [generic/ubuntu2004:3.1.16](https://app.vagrantup.com/generic/boxes/ubuntu2004/versions/3.1.16)
```
Vagrant.configure("2") do |config|
  config.vm.box = "generic/ubuntu2004"
  config.vm.box_version = "3.1.16"
end
```
- Library virtual driver is virtual box or KVM (Kernel-based Virtual Machine), here is KVM
- Using `bootstrap.sh` for installing necessary software

```
# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
    config.vm.provider :libvirt do |libvirt|
        libvirt.driver = "kvm"
    end
    config.vm.box = "generic/ubuntu2004"
    config.vm.box_version = "3.1.16"
    config.vm.provision:shell, inline: <<-SHELL
        echo "root:rootroot" | sudo chpasswd
        sudo timedatectl set-timezone Asia/Ho_Chi_Minh
    SHELL

    config.vm.define "ubuntu20.04" do |ubuntu|
        ubuntu.vm.hostname = "ubuntu20.04"
    end

    config.vm.provision:shell, path: "bootstrap.sh"
end
```

### **2. Bootstrap machine [`bootstrap.sh`](https://github.com/vumdao/vagrant/blob/master/ubuntu20.04/bootstrap.sh)**
- Install docker
- Resolve dns
- Install openSSH
- Enable root login
- Welcome message
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
    sudo apt -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    if [ $? -ne 0 ]; then
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    fi
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    sudo groupadd docker
    sudo gpasswd -a $USER docker
    sudo chmod 777 /var/run/docker.sock
    # Add vagrant to docker group
    sudo groupadd docker
    sudo gpasswd -a vagrant docker
    # Setup docker daemon host
    # Read more about docker daemon https://docs.docker.com/engine/reference/commandline/dockerd/
    sed -i 's/ExecStart=.*/ExecStart=\/usr\/bin\/dockerd -H unix:\/\/\/var\/run\/docker.sock -H tcp:\/\/192.168.121.210/g' /lib/systemd/system/docker.service
    sudo systemctl daemon-reload
    sudo systemctl restart docker
}

install_openssh() {
    step "===== Installing openssh ====="
    sudo apt update
    sudo apt -y install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
    sudo apt install -y openssh-server
    sudo systemctl enable ssh
}

install_tools() {
    sudo apt install -y python-pip
    sudo apt install -y default-jre
        pip install kafka --user
        pip install kafka-python --user
}

setup_root_login() {
    sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sudo systemctl restart ssh
    sudo echo "root:rootroot" | chpasswd
}

setup_welcome_msg() {
    sudo apt -y install cowsay
    sudo echo -e "\necho \"Welcome to Vagrant Ubuntu Server 18.04\" | cowsay\n" >> /home/vagrant/.bashrc
    sudo ln -s /usr/games/cowsay /usr/local/bin/cowsay
}

main() {
    ensure_netplan_apply
    resolve_dns
    install_openssh
    setup_root_login
    setup_welcome_msg
}

main
```

### **3. Start Vagrant**
```
⚡ $ vagrant up
Bringing machine 'ubuntu20.04' up with 'libvirt' provider...
==> ubuntu20.04: Box 'generic/ubuntu2004' could not be found. Attempting to find and install...
    ubuntu20.04: Box Provider: libvirt
    ubuntu20.04: Box Version: 3.1.16
==> ubuntu20.04: Loading metadata for box 'generic/ubuntu2004'
    ubuntu20.04: URL: https://vagrantcloud.com/generic/ubuntu2004
==> ubuntu20.04: Adding box 'generic/ubuntu2004' (v3.1.16) for provider: libvirt
    ubuntu20.04: Downloading: https://vagrantcloud.com/generic/boxes/ubuntu2004/versions/3.1.16/providers/libvirt.box
    ubuntu20.04: Download redirected to host: vagrantcloud-files-production.s3.amazonaws.com
==> ubuntu2004: Checking if box 'generic/ubuntu2004' version '3.1.16' is up to date...
==> ubuntu2004: Creating image (snapshot of base box volume).
==> ubuntu2004: Creating domain with the following settings...
==> ubuntu2004:  -- Name:              ubuntu20.04_ubuntu2004
...

⚡ $ vagrant ssh
 ___________________________________________________________
< Welcome to Vagrant Ubuntu Server 20.04 LTS (Focal Fossa) >
 -----------------------------------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
vagrant@ubuntu2004:~$ 
```
![Alt Text](https://dev-to-uploads.s3.amazonaws.com/i/gnvmy7g5m2ww165ztkdj.png)
