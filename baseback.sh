#!/bin/bash
# Setting replication, as default node1 is master, node2 is slave

run_cmd() {
	vagrant ssh node2 -c "$1"
}

node1_ip="192.168.121.210"

run_cmd "sudo systemctl stop postgresql"

run_cmd "sudo -u postgres pg_basebackup -h ${node1_ip} -U replicator -Ft -x -D - > /tmp/backup.tar"

run_cmd "sudo rm -rf /var/lib/postgresql/9.5/main/*"

run_cmd "sudo -u postgres tar xf /tmp/backup.tar -C /var/lib/postgresql/9.5/main/"

run_cmd "sudo cp /var/lib/postgresql/9.5/main/recovery.conf.temp /var/lib/postgresql/9.5/main/recovery.conf"

run_cmd "sudo systemctl start postgresql"