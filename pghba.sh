#!/bin/bash
# Update pg_hba.conf

node1_ip=`vagrant ssh-config node1 | grep HostName | awk '{print $2}'`
node2_ip=`vagrant ssh-config node2 | grep HostName | awk '{print $2}'`

cmd="sudo -u postgres sed -i \"\\\$ahost    replication     replicator      $node2_ip/32      md5\\\n\" /etc/postgresql/9.5/main/pg_hba.conf"
vagrant ssh node1 -c "$cmd"

cmd="sudo -u postgres sed -i \"\$ahost    replication     replicator      $node1_ip/32      md5\\\n\" /etc/postgresql/9.5/main/pg_hba.conf"
vagrant ssh node2 -c "$cmd"