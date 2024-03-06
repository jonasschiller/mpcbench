#!/bin/bash

# Global setup-script running locally on experiment server. 
# Initializing the experiment server

# exit on error
set -e             
# log every command
set -x                         

REPO=$(pos_get_variable repo --from-global)     
REPO_DIR=$(pos_get_variable repo_dir --from-global)
REPO2=$(pos_get_variable repo2 --from-global)
REPO2_DIR=$(pos_get_variable repo2_dir --from-global)

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
echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean false' | debconf-set-selections
export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y automake build-essential cmake git libboost-dev libboost-thread-dev \
    libntl-dev libsodium-dev libssl-dev libtool m4 texinfo yasm \
    python3-pip time parted libomp-dev htop wget gnupg software-properties-common \
    lsb-release iperf3 
pip3 install -U numpy
checkConnection "github.com"
echo 'deb http://deb.debian.org/debian testing main' > /etc/apt/sources.list.d/testing.list
#bash -c "$(wget -O - https://apt.llvm.org/llvm.sh)"
apt update -y
apt install -y gcc-12 g++-12

if ! command -v update-alternatives &> /dev/null; then
    echo "update-alternatives command not found. This script is intended for Debian/Ubuntu-based systems."
    exit 1
fi
# Set the priority for GCC-12 (adjust the path as needed)
GCC_PATH="/usr/bin/gcc-12"
GPP_PATH="/usr/bin/g++-12"
GCC_PRIORITY=100
GPP_PRIORITY=100
# Check if GCC-12 exists
if [ ! -f "$GCC_PATH" ]; then
    echo "GCC-12 not found at $GCC_PATH. Please make sure it is installed."
    exit 1
fi
# Check if G++-12 exists
if [ ! -f "$GPP_PATH" ]; then
    echo "g++-12 not found at $GPP_PATH. Please make sure it is installed."
    exit 1
fi
# Register GCC-12 as an alternative to the default GCC
update-alternatives --install /usr/bin/gcc gcc "$GCC_PATH" "$GCC_PRIORITY"
# Register G++-12 as an alternative to the default C++
update-alternatives --install /usr/bin/g++ g++ "$GPP_PATH" "$GPP_PRIORITY"
# Select GCC-12 as the default
update-alternatives --set gcc "$GCC_PATH"
# Select G++-12 as the default
update-alternatives --set g++ "$GPP_PATH"
# Display the current default version
echo "GCC-12 is now the default GCC version."
gcc --version
g++ --version
echo "$(gcc --version)"

git clone "$REPO" "$REPO_DIR"
git clone "$REPO2" "$REPO2_DIR"

# load custom htop config
mkdir -p .config/htop
cp "$REPO2_DIR"/helpers/htoprc ~/.config/htop/
cd "$REPO_DIR"
mkdir build
cd build
cmake .. -DMOTION_BUILD_EXE=On
# determine the number of jobs for compiling via available ram and cpu cores
maxcoresram=$(($(grep "MemTotal" /proc/meminfo | awk '{print $2}')/(1024*2500)))
maxcorescpu=$(($(nproc --all)-1))
# take the minimum of the two options
maxjobs=$(( maxcoresram < maxcorescpu ? maxcoresram : maxcorescpu ))
make -j "$maxjobs" all
make install
cd /root
chmod 777 /root/sevarebenchmotion /root/MOTION -R
echo "global setup successful"
