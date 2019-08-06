#!/bin/bash
# Bootstrap machine

other_ip="192.168.121.211"
if [ "$(hostname)" == "node2" ]; then
    other_ip="192.168.121.210"
fi

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

install_postgresql() {
    step "===== Installing postgresql ====="
    sudo wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    sudo echo "deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main" >> /etc/apt/sources.list.d/pgdg.list
    sudo apt-get update
    sudo apt-get -y install postgresql-9.5 
    sudo apt-get -y install postgresql-client-9.5

    step "===== Patching pg_hba.conf ====="
    sudo printf "\nhost    all             all             127.0.0.1/32            trust\n" >> /etc/postgresql/9.5/main/pg_hba.conf
    sudo printf "\nhost    all             all             all                     md5\n" >> /etc/postgresql/9.5/main/pg_hba.conf
    sudo printf "\nlisten_addresses = '*'" >> /etc/postgresql/9.5/main/postgresql.conf
    sudo printf "\nhost    replication     replicator      $other_ip/32      md5\n" >> /etc/postgresql/9.5/main/pg_hba.conf
    sudo service postgresql restart

    step "===== Changing pasword ====="
    sudo -u postgres psql postgres -c "ALTER USER postgres WITH ENCRYPTED PASSWORD 'postgres'"
}

install_pgbouncer() {
    step "===== Install pgbouncer ====="
    sudo apt-get -y install postgresql-server-dev-9.5
    sudo apt-get -y install libevent-dev
    sudo apt-get -y install pgbouncer

    step "===== Config pgbouncer: Add userlist ====="
    cd /etc/pgbouncer
    sudo cat > config_pgbouncer <<EOF
COPY (
SELECT '"' || rolname || '" "' ||
CASE WHEN rolpassword IS null THEN '' ELSE rolpassword END || '"'
FROM pg_authid
)
TO '/etc/pgbouncer/userlist.txt';
EOF

    sudo chmod 777 config_pgbouncer
    sudo -u postgres psql < config_pgbouncer

    step "===== Config pgbouncer: Update pgbouncer.ini ====="
    sudo chmod 777 pgbouncer.ini
    sudo sed -i 's/\[databases\]/\[databases\]\npostgres = host=localhost/' pgbouncer.ini
    sudo sed -i 's/listen_addr.*/listen_addr = \*/' pgbouncer.ini
    sudo sed -i 's/auth_type.*/auth_type = trust/' pgbouncer.ini
    sudo printf "\nadmin_users = postgres\n" >> pgbouncer.ini
    sudo sed -i 's/max_client_conn = .*/max_client_conn = 500/' pgbouncer.ini
    sudo sed -i 's/default_pool_size =.*/default_pool_size = 25/' pgbouncer.ini
    sudo printf "\nreserve_pool_size = 5\n" >> pgbouncer.ini
    sudo systemctl restart pgbouncer
}

create_replicator_user() {
    step "===== Create replicator user for nodes ====="
    sudo cat > /tmp/user <<EOF
CREATE USER replicator
WITH REPLICATION
ENCRYPTED PASSWORD 'rootroot';
EOF
    sudo chmod 777 /tmp/user
    sudo -u postgres psql < /tmp/user
}

replica_setup() {
    step "===== Setup replication configuration ====="
    sudo echo -e "
wal_level = hot_standby
wal_log_hints = on
archive_mode = on
archive_command = 'test ! -f /vagrant/replica/%f && cp %p /vagrant/replica/%f'
max_wal_senders = 2
wal_keep_segments = 1000
hot_standby = on" >> /etc/postgresql/9.5/main/postgresql.conf
}

create_recover_temp() {
    step "===== create_recover_temp ====="
    sudo -u postgres echo -e "
standby_mode = 'on'
primary_conninfo = 'user=replicator password=rootroot host=${other_ip} port=5432 sslmode=prefer sslcompression=0 krbsrvname=postgres target_session_attrs=any'
recovery_target_timeline = 'latest'
restore_command = 'cp /vagrant/replica/%f %p'
archive_cleanup_command = 'pg_archivecleanup /vagrant/replica %r'
trigger_file = '/tmp/pg-trigger-failover-now'" >> /var/lib/postgresql/9.5/main/recovery.conf.temp
}

setup_welcome_msg() {
    sudo apt-get -y install cowsay
    sudo echo -e "\n echo \"Welcome to Vagrant Postgres Ubuntu 18.04\" | cowsay\n" >> /home/vagrant/.bashrc
    sudo ln -s /usr/games/cowsay /usr/local/bin/cowsay
}

postgres_bashrc() {
    bashrc="/var/lib/postgresql/.bashrc"
    sudo -u postgres echo "alias pgconf=\"cd /etc/postgresql/9.5/main\"" >> $bashrc
    sudo -u postgres echo "alias pgdir=\"cd /var/lib/postgresql/9.5/main\"" >> $bashrc
    sudo -u postgres echo -e "\n echo \"Hey! I'm postgres user\" | cowsay -f apt\n" >> $bashrc
}

main() {
    resolve_dns
    install_postgresql
    install_pgbouncer
    create_replicator_user
    replica_setup
    create_recover_temp
    setup_welcome_msg
    postgres_bashrc
}

main