#!/bin/bash
# Replication set
replica_setup() {
    step "===== Setup replication configuration ====="
    echo -e "
wal_level = hot_standby
wal_log_hints = on
archive_mode = on
archive_command = 'test ! -f /vagrant/replica/%f && cp %p /vagrant/replica/%f'
max_wal_senders = 2
wal_keep_segments = 1000
hot_standby = on" >> /etc/postgresql/9.5/main/postgresql.conf

    if [ "$(hostname)" == "node1" ]; then
        echo "host    replication     replicator      ${node2_ip}/32       md5" >> /etc/postgresql/9.5/main/pg_hba.conf
    else
        echo "host    replication     replicator      ${node1_ip}/32       md5" >> /etc/postgresql/9.5/main/pg_hba.conf
    fi
}

base_backup() {
    sudo mkdir -p /vagrant/replica
    sudo chown -R postgres:postgres /vagrant/replica

    if [ "$(hostname)" != "node1" ]; then
        sudo su postgres pg_basebackup -h ${node1_ip} -U replicator -Ft -x -R -D - > /tmp/backup.tar
        sudo systemctl stop postgresql
        sudo rm -rf /var/lib/postgresql/9.5/main/*
        sudo su postgres tar xf /tmp/backup.tar -C /var/lib/postgresql/9.5/main/
        sudo su postgres echo "
recovery_target_timeline = 'latest'
restore_command = 'cp /vagrant/replica/%f %p'
archive_cleanup_command = 'pg_archivecleanup /vagrant/replica %r'

# SLAVE PROMOTION
# or use: `sudo pg_ctlcluster 9.5 main promote`
trigger_file = '/tmp/pg-trigger-failover-now'" >> /var/lib/postgresql/9.5/main/recovery.conf
        sudo systemctl start postgresql
    fi
}

node1_ip="$1"
node2_ip="$2"

replica_setup
base_backup