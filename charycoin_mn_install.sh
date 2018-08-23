#!/bin/bash
#
# Copyright (C) 2018 CharyCoin Team
#
# mn_install.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# mn_install.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with mn_install.sh. If not, see <http://www.gnu.org/licenses/>
#

# Only Ubuntu 16.04 supported at this moment.

set -o errexit

# OS_VERSION_ID=`gawk -F= '/^VERSION_ID/{print $2}' /etc/os-release | tr -d '"'`

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
sudo apt install curl wget git python3 python3-pip virtualenv -y

XRC_DAEMON_USER_PASS=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32 ; echo ""`
XRC_DAEMON_RPC_PASS=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 ; echo ""`
MN_NAME_PREFIX=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6 ; echo ""`
MN_EXTERNAL_IP=`curl -s -4 ifconfig.co`

sudo useradd -U -m charycoin -s /bin/bash
echo "charycoin:${XRC_DAEMON_USER_PASS}" | sudo chpasswd
sudo wget https://github.com/charycoin/charycoin/releases/download/v0.7.1.1/charycoin-0.7.1.1-cli-linux.tar.gz --directory-prefix /home/charycoin/
sudo tar -xzvf /home/charycoin/charycoin-0.7.1.1-cli-linux.tar.gz -C /home/charycoin/
sudo rm /home/charycoin/charycoin-0.7.1.1-cli-linux.tar.gz
sudo mkdir /home/charycoin/.charycoincore/
sudo chown -R charycoin:charycoin /home/charycoin/charycoin*
sudo chmod 755 /home/charycoin/charycoin*
echo -e "rpcuser=charycoinrpc\nrpcpassword=${XRC_DAEMON_RPC_PASS}\nlisten=1\nserver=1\nrpcallowip=127.0.0.1\nmaxconnections=256" | sudo tee /home/charycoin/.charycoincore/charycoin.conf
sudo chown -R charycoin:charycoin /home/charycoin/.charycoincore/
sudo chown 500 /home/charycoin/.charycoincore/charycoin.conf

sudo tee /etc/systemd/system/charycoin.service <<EOF
[Unit]
Description=CharyCoin, distributed currency daemon
After=network.target

[Service]
User=charycoin
Group=charycoin
WorkingDirectory=/home/charycoin/
ExecStart=/home/charycoin/charycoind

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=2s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable charycoin
sudo systemctl start charycoin
echo "Booting XRC node and creating keypool"
sleep 140

MNGENKEY=`sudo -H -u charycoin /home/charycoin/charycoin-cli masternode genkey`
echo -e "masternode=1\nmasternodeprivkey=${MNGENKEY}\nexternalip=${MN_EXTERNAL_IP}:11055" | sudo tee -a /home/charycoin/.charycoincore/charycoin.conf
sudo systemctl restart charycoin

echo "Installing sentinel engine"
sudo git clone https://github.com/charycoin/sentinel.git /home/charycoin/sentinel/
sudo chown -R charycoin:charycoin /home/charycoin/sentinel/
cd /home/charycoin/sentinel/
sudo -H -u charycoin virtualenv -p python3 ./venv
sudo -H -u charycoin ./venv/bin/pip install -r requirements.txt
echo "* * * * * charycoin cd /home/charycoin/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" | sudo tee /etc/cron.d/charycoin_sentinel
sudo chmod 644 /etc/cron.d/charycoin_sentinel

echo " "
echo " "
echo "==============================="
echo "Masternode installed!"
echo "==============================="
echo "Copy and keep that information in secret:"
echo "Masternode key: ${MNGENKEY}"
echo "SSH password for user \"charycoin\": ${XRC_DAEMON_USER_PASS}"
echo "Prepared masternode.conf string:"
echo "mn_${MN_NAME_PREFIX} ${MN_EXTERNAL_IP}:11055 ${MNGENKEY} INPUTTX INPUTINDEX"

exit 0
