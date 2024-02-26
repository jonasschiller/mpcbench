#!/bin/bash
if [ "${#@}" -ne 3 ]; then
    echo "Checks every 10 Minutes if <configfile> experiment can be run next and runs it"
    echo "Usage:"
    echo "  bash helpers/scheduler.sh <configfile> <nodes> <logfile> > schedulog &"
    echo "Example"
    echo "  bash helpers/scheduler.sh configs/ex31/Hon-cpu.conf valga,tapa,rapla sevarelog_valga11 > schedulog &"
    exit
fi
config=$1
nodes=$2
logfile=$3
while :; do
    nodetasks=$(pgrep -facu "$(id -u)" "$nodes")
    if [ "$nodetasks" -lt 2 ]; then
        bash sevarebench.sh --config "$config" "$nodes" &> "$logfile" &
        break
    fi
    echo "sleep until $(date) + 10min"
    sleep 600
done

