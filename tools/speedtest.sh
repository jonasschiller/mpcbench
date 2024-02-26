#!/bin/bash

# install tool
apt update && apt install iperf3 -y

# set up recommended MTU
#ip link set dev <NIC> mtu 9000

hostname=10.10."$(ip a | grep "10.10." | head -n 1 | cut -d '.' -f 3)".2
threads=10
pids=()

## server
stopserver() {
    for pid in "${pids[@]}"; do
        kill -15 "$pid"
    done
    pids=()
}
startserver() {
    stopserver
    logfile=speedtestlog"$(date +20%y-%m-%d_%H-%M-%S)"
    echo "logfile is $logfile"
	for i in $(seq 1 $threads); do
        iperf3 -s -p 510"$i" &>> "$logfile" &
        pids+=( $! )
    done
}

## client
startclient() {
    pids=()
    logfile=speedtestlog"$(date +20%y-%m-%d_%H-%M-%S)"
    echo "logfile is $logfile and hostname is $hostname"
    for i in $(seq 1 "$threads"); do
        iperf3 -f g -c "$hostname" -T s"$i" -p 510"$i" &>> "$logfile" &
        pids+=( $! )
    done
    echo "waiting for test to finish"
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    cat "$logfile"

    unit=$(grep "sender" "$logfile" | awk '{print $9}' | tail -n 1)
    echo -e "\n\n\n   ### Test Summary: ###\n\n"
    grep "sender" "$logfile"
    sum=$(grep "sender" "$logfile" | awk '{print $8}' | paste -s -d+ | bc)
    echo -e "\ntotal sender speed: $sum $unit\n"

    grep "receiver" "$logfile"
    sum=$(grep "receiver" "$logfile" | awk '{print $8}' | paste -s -d+ | bc)
    echo -e "\ntotal receiver speed: $sum $unit\n"
}

hostname="$hostname"
threads="$threads"

ping -q -c 2 "$hostname" &>> /dev/null || echo "host $hostname unreachable, abort"

#startserver
#startclient

findDistribution() {
    echo "server is $hostname"
    for i in $(seq 1 10); do
        threads="$i"
        echo -e "\n Threads: $i"
        startclient | grep total
    done
}

#findDistribution