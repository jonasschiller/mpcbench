#!/bin/bash

# Global setup-script running locally on experiment server. 
# Initializing the experiment server

# exit on error
set -e             
# log every command
set -x                         

REPO=$(pos_get_variable repo_mpspdz --from-global)
#REPO_COMMIT=$(pos_get_variable repo_commit --from-global)       
REPO_DIR=$(pos_get_variable repo_mpspdz_dir --from-global)
REPO2=$(pos_get_variable repo --from-global)
REPO2_DIR=$(pos_get_variable repo_dir --from-global)
EXPERIMENT=$(pos_get_variable experiment --from-global)
FRAMEWORK=$(pos_get_variable framework --from-global)
# SMC protocols to compile


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

#######
#### compile libaries and prepare experiments
#######





checkConnection "mirror.lrz.de"
apt update
apt install -y automake git libboost-dev libboost-thread-dev \
    libntl-dev libgmp-dev libsodium-dev libssl-dev libtool m4 python3 texinfo yasm \
    python3-pip time parted software-properties-common
pip3 install -U numpy torch
checkConnection "github.com"
git clone "$REPO2" "$REPO2_DIR"

# load custom htop config
mkdir -p .config/htop
cp "$REPO2_DIR"/helpers/htoprc ~/.config/htop/
wget https://github.com/data61/MP-SPDZ/releases/download/v0.3.8/mp-spdz-0.3.8.tar.xz
tar -xf mp-spdz-0.3.8.tar.xz 
mv mp-spdz-0.3.8 "$REPO_DIR"
cd "$REPO_DIR"
./Scripts/tldr.sh


cp "$REPO2_DIR"/experiments/"$FRAMEWORK"/"$EXPERIMENT"/experiment.mpc \
	"$REPO_DIR"/Programs/Source/
# experiment specific part: load the input from the experiment into the Player Data folder of MP-SPDZ
if [ -f "$REPO2_DIR"/experiments/"$FRAMEWORK"/"$EXPERIMENT"/aes_128.txt ]; then
    cp "$REPO2_DIR"/experiments/"$FRAMEWORK"/"$EXPERIMENT"/aes_128.txt "$REPO_DIR"/Programs/Circuits/
fi
chmod +x "$REPO2_DIR"/helpers/* "$REPO2_DIR"/experiments/"$FRAMEWORK"/"$EXPERIMENT"/*
cd "$REPO_DIR"

tar -xf "$REPO2_DIR"/helpers/SSLcerts.tar

# activate BMR MultiParty
sed -i 's/#define MAX_N_PARTIES 3/\/\/#define MAX_N_PARTIES 3/' BMR/config.h

# add custom compile flags
compflags=$(pos_get_variable compflags --from-global)

if [ "$compflags" != None ]; then
	if [ -f CONFIG.mine ]; then
		sed -i "/^MY_CFLAGS/ s/$/ $compflags/" CONFIG.mine
	else
		echo "MY_CFLAGS += $compflags" >> CONFIG.mine
	fi
fi
echo "global setup successful "