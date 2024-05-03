#!/bin/bash

# This script performs the basic setup of the experiment server and its network connections
# Furthermore it performs a speed test of each connection and stores the result for future output.
# It does not need to be adapted for the integration of a new framework
# The first step is the identification of the nodes and the associated topology.
# Then the network drivers and ip adresses are set to match the corresponding node.
# For the faster intel nodes, a specific network driver is installed allowing for bandwidths up to 25 GBit/s
# Finally the speed test is performed.
# If desired, this script also sets up the required settings to measure the amount of RAM page swaps.


# exit on error
set -e
# log every command
set -x

REPO_DIR=$(pos_get_variable repo_dir --from-global)

# SMC protocols to compile
ipaddr="$1"
SWAP="$2"
network="$3"
read -r -a nodes <<< "$4"
groupsize=${#nodes[*]}


#######
#### set networking environment
#######

# driver for Intel Network Adapter for E810 100G card
installDriver() {
	wget https://downloadmirror.intel.com/812404/ice-1.13.7.tar.gz
	tar -xf ice-1.13.7.tar.gz
	cd ice-1.13.7/src/
	make install &> makelog || true
	cd ..
	mkdir -p /lib/firmware/updates/intel/ice/ddp/
	cp ddp/ice-1.3.35.0.pkg /lib/firmware/updates/intel/ice/ddp/
	modprobe -r ice
	modprobe ice
}

# If the testnodes are directly connected from NIC to NIC and
# not via a switch, we need to create individual networks for each
# NIC pair and route the network through the correct NIC
# this is not an ideal situation for big party numbers
if [ "$groupsize" -eq 3 ] && [ (hostname | grep -cE "idex|meld|tinyman|yieldly|algofi|gard|goracle|zone") ]; then
	nic0=$(pos_get_variable "$(hostname)"NIC0_3node --from-global)
	nic1=$(pos_get_variable "$(hostname)"NIC1_3node --from-global) || nic1=0
else
	nic0=$(pos_get_variable "$(hostname)"NIC0 --from-global)
	nic1=$(pos_get_variable "$(hostname)"NIC1 --from-global) || nic1=0
	nic2=$(pos_get_variable "$(hostname)"NIC2 --from-global) || nic2=0
fi


ips=()

# four nodes direct connection topology if true
if [ "$nic1" != 0 ] && [ "$nic2" != 0 ]  && [ "$groupsize" == 4 ]; then

	# to achieve high speeds, install ddp drivers
	highspeed=$(hostname | grep -cE "idex|meld|tinyman|yieldly|algofi|gard|goracle|zone")
	[ "$highspeed" -eq 1 ] && installDriver

	# verify that nodes array is circularly sorted
	# this is required for the definition of this topology
	
	# specify the ip pair to create the network routes to
	# it's not the ip that is being set to this host
	[ "$ipaddr" -eq 2 ] && ips+=( 3 4 5 )
	[ "$ipaddr" -eq 3 ] && ips+=( 4 5 2 )
	[ "$ipaddr" -eq 4 ] && ips+=( 5 2 3 )
	[ "$ipaddr" -eq 5 ] && ips+=( 2 3 4 )

	ip addr add 10.10."$network"."$ipaddr"/24 dev "$nic0"
	ip addr add 10.10."$network"."$ipaddr"/24 dev "$nic1"
	ip addr add 10.10."$network"."$ipaddr"/24 dev "$nic2"

	ip link set dev "$nic0" up
	ip link set dev "$nic1" up
	ip link set dev "$nic2" up

	ip route add 10.10."$network"."${ips[0]}" dev "$nic0"
	ip route add 10.10."$network"."${ips[1]}" dev "$nic1"
	ip route add 10.10."$network"."${ips[2]}" dev "$nic2"

	# to achieve high speeds, increase mtu
	if [ "$highspeed" -eq 1 ]; then
		ip link set dev "$nic0" mtu 9700
		ip link set dev "$nic1" mtu 9700
		ip link set dev "$nic2" mtu 9700
	fi

# three nodes direct connection topology if true
elif [ "$nic1" != 0 ] && [ "$groupsize" == 3 ]; then

	# to achieve high speeds, install ddp drivers
	highspeed=$(hostname | grep -cE "idex|meld|tinyman|yieldly|algofi|gard|goracle|zone")
	[ "$highspeed" -eq 1 ] && installDriver

	sleep 20

	# verify that nodes array is circularly sorted
	# this is required for the definition of this topology
	
	# specify the ip pair to create the network routes to
	# it's not the ip that is being set to this host
	[ "$ipaddr" -eq 2 ] && ips+=( 3 4 )
	[ "$ipaddr" -eq 3 ] && ips+=( 4 2 )
	[ "$ipaddr" -eq 4 ] && ips+=( 2 3 )

	ip addr add 10.10."$network"."$ipaddr"/24 dev "$nic0"
	ip addr add 10.10."$network"."$ipaddr"/24 dev "$nic1"

	ip link set dev "$nic0" up
	ip link set dev "$nic1" up

	ip route add 10.10."$network"."${ips[0]}" via 10.10."$network"."$ipaddr" dev "$nic0"
	ip route add 10.10."$network"."${ips[1]}" via 10.10."$network"."$ipaddr" dev "$nic1"

	# to achieve high speeds, increase mtu
	if [ "$(hostname | grep -cE "idex|meld|tinyman|yieldly|gard|goracle|zone")" -eq 1 ]; then
		ip link set dev "$nic0" mtu 9700
		ip link set dev "$nic1" mtu 9700
	fi

# here the testhosts are connected via switch
else
	# support any groupsizes
	# store other participants ips
	for i in $(seq 2 $((groupsize+1))); do
		[ "$ipaddr" -ne "$i" ] && ips+=( "$i" )
	done

	ip addr add 10.10."$network"."$ipaddr"/24 dev "$nic0"
	ip link set dev "$nic0" up

fi

# wait for others to finish setup
pos_sync

###
# Networking tests

# don't start test simultaneously
sleep $((ipaddr-2))

# log link test
for ip in "${ips[@]}"; do
	ping -c 5 10.10."$network"."$ip" &>> pinglog || true
done

pos_upload pinglog

# # log link test
# # shellcheck source=../tools/speedtest.sh
source "$REPO_DIR"/tools/speedtest.sh

{
	startserver

	for serverip in $(seq 2 $((groupsize+1))); do
		for clientip in $(seq 2 $((groupsize+1))); do
			pos_sync
			# skip the server
			[ "$serverip" -eq "$clientip" ] && continue
			# skip other clients for now
			[ "$ipaddr" -ne "$clientip" ] && continue
			# skip the client server roles repetitions, this is here explicitly and not 
			# merged with case one so that this can be deactivated easily if wanted
			[ "$serverip" -gt "$clientip" ] && continue			

			hostname="${hostname::-1}$serverip"
			echo "measured speed between nodes $((serverip-1)) and $((clientip-1))"
			for k in 1 10; do
					threads="$k"
					echo -e "\n Threads: $k"
					startclient | grep total
			done
		done
	done
} > speedtest

stopserver

pos_upload speedtest


# set up swap disk for RAM pageswapping measurements
if [ -n "$SWAP" ] && [ -b /dev/nvme0n1 ]; then
	echo "creating swapfile with swap size $SWAP"
	parted -s /dev/nvme0n1 mklabel gpt
	parted -s /dev/nvme0n1 mkpart primary ext4 0% 100%
	mkfs.ext4 -FL swap /dev/nvme0n1
	mkdir /swp
	mkdir /whale
	mount -L swap /swp
	dd if=/dev/zero of=/swp/swp_file bs=1024 count="$SWAP"K
	chmod 600 /swp/swp_file
	mkswap /swp/swp_file
	swapon /swp/swp_file
	 # create ramdisk
    totalram=$(free -m | grep "Mem:" | awk '{print $2}')
	mount -t tmpfs -o size="$totalram"M swp /whale
	# preoccupy ram and only leave 16 GiB for faster experiment runs
	# it was observed, that more than that was never required and 
	# falloc is slow in loops on nodes with large ram
	ram=$((16*1024))
	availram=$(free -m | grep "Mem:" | awk '{print $7}')
	fallocate -l $((availram-ram))M /whale/filler
fi


cd "$REPO_DIR"

tar -xf "$REPO_DIR"/helpers/SSLcerts.tar

# abort if no success
$success

echo "experiment setup successful"

