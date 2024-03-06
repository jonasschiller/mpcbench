#!/bin/bash
# shellcheck disable=SC1091,2154

# This script calls the network and system manipulation functions and, if necessary, compiles the MPC eperiment.
# It is highly dependend on the execution format of the framework  
# The network and system manipulation phase however is framework independent and can be reused for other frameworks.
# Script is run locally on experiment server.
#

# exit on error
set -e
# log every command
set -x
#####
# Framework independent
REPO_DIR=$(pos_get_variable repo_dir --from-global)
timerf="%M (Maximum resident set size in kbytes)\n%e (Elapsed wall clock time in seconds)\n%P (Percent of CPU this job got)\n%S (System time in seconds)"
size=$(pos_get_variable input_size --from-loop)
### add custom aprameters
param2=$(pos_get_variable input2_size --from-loop) || param2=""
###
EXPERIMENT=$1
player=$2
environ=""
# test types to simulate changing environments like cpu frequency or network latency
read -r -a types <<< "$3"
network="$4"
partysize=$5
# experiment type to allow small differences in experiments
etype=$6
# default to etype 1 if unset
etype=${etype:-1}


####
#  environment manipulation section start
####
# shellcheck source=../host_scripts/manipulate.sh
source "$REPO_DIR"/host_scripts/manipulate.sh

if [[ "${types[*]}" == *" LATENCY=0 "* ]]; then
    types=("${types[@]/LATENCY}")
fi


case " ${types[*]} " in
    *" CPUS "*)
        limitCPUs;;&
    *" RAM "*)
        limitRAM;;&
    *" QUOTAS "*)
        setQuota;;&
    *" FREQS "*)
        setFrequency;;&
    *" BANDWIDTHS "*)
        # check whether to manipulate a combination
        case " ${types[*]} " in
            *" LATENCIES "*)
            case " ${types[*]} " in
                *" PACKETDROPS "*)
                    setAllParameters;;
                *)
                setLatencyBandwidth;;
            esac;;                 
            *" PACKETDROPS "*) # a.k.a. packet loss
                setBandwidthPacketdrop;;
            *)
                limitBandwidth;;
        esac;;
    *" LATENCIES "*)
        if [[ " ${types[*]} " == *" PACKETDROPS "* ]]; then
            setPacketdropLatency
        else
            setLatency
        fi;;
    *" PACKETDROPS "*)
        setPacketdrop;;
esac

####
#  environment manipulation section stop
####
###
# Framework dependent experiment compilation and execution
###
log=testresults
touch "$log"

success=true

pos_sync --timeout 300

# Some protocols are only for 2,3 or 4 parties
# they imply the flag -N so it's not allowed
extraflag="-N $partysize"
# need to skip for some nodes
skip=false

# Format Parameter String use -P addr:port option per party
partystring=""
for i in $(seq 2 $((partysize+1))); do
    partystring+=" -P 10.10."$network"."$i":23000"
done
if [ -n "$param2" ]; then
    # run the SMC protocol
    $skip || /usr/bin/time -f "$timerf" python /root/sevarebenchmpyc/experiments/"$EXPERIMENT"/experiment.py $partystring -I $player $size $param2 &> "$log" || success=false
else
    # run the SMC protocol
    $skip || /usr/bin/time -f "$timerf" python /root/sevarebenchmpyc/experiments/"$EXPERIMENT"/experiment.py $partystring -I $player $size &> "$log" || success=false
fi


pos_upload --loop "$log"

#abort if no success
$success

pos_sync


###
# Framework indepentend part
####
#  environment manipulation reset section start
####

case " ${types[*]} " in

    *" FREQS "*)
        resetFrequency;;&
    *" RAM "*)
        unlimitRAM;;&
    *" BANDWIDTHS "*|*" LATENCIES "*|*" PACKETDROPS "*)
    	resetTrafficControl;;&
    *" CPUS "*)
        unlimitCPUs
esac

####
#  environment manipulation reset section stop
####

pos_sync --loop
