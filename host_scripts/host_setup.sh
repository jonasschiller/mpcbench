#!/bin/bash

# Global setup-script running locally on experiment server. 
# Initializing the experiment server

# exit on error
set -e             
# log every command
set -x                         

REPO=$(pos_get_variable repo --from-global)
REPO_DIR=$(pos_get_variable repo_dir --from-global)

# check WAN connection, waiting helps in most cases
checkConnection() {
    address=$1
    i=0
    maxtry=5
    success=false
    while [ $i -lt $maxtry ] && ! $success; do
        success=true
        echo "____ping $1 try $i" >> pinglog_external
        ping -q -c 2 "$address" >> pinglog_external || success=false
        ((++i))
        sleep 2s
    done
    $success
}
checkConnection "mirror.lrz.de"
apt update
apt install -y git m4 python3 texinfo yasm linux-cpupower \
    python3-pip time parted libomp-dev htop
pip3 install -U numpy
pip3 install -U gmpy2
pip3 install -U mpyc
checkConnection "github.com"
git clone "$REPO" "$REPO_DIR"
chmod -R 770 "$REPO_DIR"
# load custom htop config
mkdir -p .config/htop
cp "$REPO_DIR"/helpers/htoprc ~/.config/htop/

echo "host_setup complete"