#!/bin/sh

##
# Dependencies
# - systemd
echo '# Boruta server setup'
echo '## install dependencies'
apt-get -q update
apt-get -q install -y libssl-dev wget vim postgresql postgresql-client

echo '## install boruta'
cd /opt
wget -q https://github.com/malach-it/boruta-server/releases/download/0.3.0/boruta.tar.gz
tar xf boruta.tar.gz

wget -q -O /opt/boruta/.env.production https://raw.githubusercontent.com/malach-it/boruta-server/0.3.0/.env.example
vim /opt/boruta/.env.production

cat > /etc/systemd/system/boruta.service <<- EOF
[Unit]
Description=Boruta server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/boruta
EnvironmentFile=/opt/boruta/.env.production
ExecStartPre=-su -w POSTGRES_USER,POSTGRES_PASSWORD - postgres -c "psql -c \"CREATE USER \${POSTGRES_USER} WITH CREATEDB PASSWORD '\${POSTGRES_PASSWORD}'\""
ExecStartPre=/opt/boruta/bin/boruta eval "Boruta.Release.setup()"
ExecStart=/opt/boruta/bin/boruta start
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
chmod +x /etc/systemd/system/boruta.service


echo '## Enable boruta service'
systemctl daemon-reload
systemctl enable boruta
systemctl start boruta

exit 0
