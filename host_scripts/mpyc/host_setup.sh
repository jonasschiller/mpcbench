#!/bin/bash

# This script downloads and installs the required packages for the framework and installs it.
# It is executed on each server participating in the experiment but triggered remotely.
# This is highly dependend on the framework, but generally mirrors the installation information provided by each framework
# In addition to that, some packages required for benchmark execution are installed such as time, git and linux-cpupower
# As most frameworks are stored in github repos, usually the respective git repo is cloned.
# Additionally, the benchmarking tool is downloaded, as the next scripts are executed locally.
# Then the build steps are followed until the framework is installed on each server.

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
# Check the connection to the WAN
checkConnection "mirror.lrz.de"
apt update
# Install dependencies
apt install -y git m4 python3 texinfo yasm linux-cpupower \
    python3-pip time parted libomp-dev htop
# install the framework
pip3 install -U numpy
pip3 install -U gmpy2
pip3 install -U mpyc
# Clone the benchmarking tool 
checkConnection "github.com"
git clone "$REPO" "$REPO_DIR"
chmod -R 770 "$REPO_DIR"
# load custom htop config
mkdir -p .config/htop
cp "$REPO_DIR"/helpers/htoprc ~/.config/htop/

echo "host_setup complete"