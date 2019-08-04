#!/bin/bash
# Bootstrap machine

step=1
step() {
	echo "Step $step $1"
	step=$((step+1))
}

if [ "$(hostname)" != "node1" ]; then
	echo "Waiting a bit for node1 update repo"
	sleep 15
fi

step "===== Installing postgresql ====="
sudo apt-get update
if [ $? -ne 0 ]; then
    sudo apt-get update
fi
sudo apt-get -y install postgresql-9.5 
sudo apt-get -y install postgresql-client-9.5

step "===== Patching pg_hba.conf ====="
sudo printf "\nhost    all             all             127.0.0.1/32            trust\n" >> /etc/postgresql/9.5/main/pg_hba.conf
sudo printf "\nhost    all             all             all                     md5\n" >> /etc/postgresql/9.5/main/pg_hba.conf
sudo printf "\nlisten_addresses = '*'" >> /etc/postgresql/9.5/main/postgresql.conf
sudo service postgresql restart

step "===== Changing pasword ====="
sudo -u postgres psql postgres -c "ALTER USER postgres WITH ENCRYPTED PASSWORD 'postgres'"

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
