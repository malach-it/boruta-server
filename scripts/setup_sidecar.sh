#!/bin/sh

##
# Dependencies
# - systemd
echo '## install dependencies'
apt update
apt install -y libssl-dev wget vim
echo '## install sidecar'
cd /opt
wget https://github.com/malach-it/boruta-server/releases/download/service-mesh.alpha.2/boruta_gateway.tar.gz
tar xf boruta_gateway.tar.gz

wget -O /opt/boruta_gateway/.env.production https://raw.githubusercontent.com/malach-it/boruta-server/service-mesh.alpha.2/.env.sidecar
vim /opt/boruta_gateway/.env.production
wget -O /opt/boruta_gateway/sidecar-configuration.yml https://raw.githubusercontent.com/malach-it/boruta-server/master/static_config/example-httpbin-configuration.yml
vim /opt/boruta_gateway/sidecar-configuration.yml
echo """
[Install]

[Unit]
Description=Boruta sidecar
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/boruta_gateway
EnvironmentFile=/opt/boruta_gateway/.env.production
Environment='BORUTA_GATEWAY_CONFIGURATION_PATH=/opt/boruta_gateway/sidecar-configuration.yml'
ExecStartPre=/opt/boruta_gateway/bin/boruta_gateway eval 'BorutaGateway.Release.setup()'
ExecStartPre=-/opt/boruta_gateway/bin/boruta_gateway eval 'BorutaGateway.Release.load_configuration()'
ExecStart=/opt/boruta_gateway/bin/boruta_gateway start
Restart=on-failure

[Install]
WantedBy=multi-user.target
""" > /etc/systemd/system/boruta_gateway.service
chmod +x /etc/systemd/system/boruta_gateway.service
systemctl daemon-reload
systemctl enable boruta_gateway
systemctl start boruta_gateway
## register sidecar
## Setup system wide https proxy
## organization ca certificate
