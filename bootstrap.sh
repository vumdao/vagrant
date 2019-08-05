#!/bin/bash
# Bootstrap machine

step=1
step() {
    echo "Step $step $1"
    step=$((step+1))
}

sleep 5

step "===== Ensure the network is ready ====="
ping -c 3 8.8.8.8

install_postgresql() {
    step "===== Installing postgresql ====="
    sudo apt-get update
    sudo wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    sudo echo "deb http://apt.postgresql.org/pub/repos/apt/ bionic-pgdg main" >> /etc/apt/sources.list.d/pgdg.list
    sudo apt-get update
    sudo apt-get -y install postgresql-9.5 
    sudo apt-get -y install postgresql-client-9.5

    step "===== Patching pg_hba.conf ====="
    sudo printf "\nhost    all             all             127.0.0.1/32            trust\n" >> /etc/postgresql/9.5/main/pg_hba.conf
    sudo printf "\nhost    all             all             all                     md5\n" >> /etc/postgresql/9.5/main/pg_hba.conf
    sudo printf "\nlisten_addresses = '*'" >> /etc/postgresql/9.5/main/postgresql.conf
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

main() {
    install_postgresql
    install_pgbouncer
    create_replicator_user
}

main