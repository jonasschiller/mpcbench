#!/bin/bash
# shellcheck disable=SC1091,2154

#
# Script is run locally on experiment server.
#

# exit on error
set -e
# log every command
set -x

REPO_DIR=$(pos_get_variable repo_mpspdz_dir --from-global)
REPO2_DIR=$(pos_get_variable repo_dir --from-global)
source "$REPO2_DIR"/host_scripts/mp-spdz/protocols.sh
EXPERIMENT=$(pos_get_variable experiment --from-global)
runflags=$(pos_get_variable runflags --from-global)
[ "$runflags" == None ] && runflags=""
size=$(pos_get_variable input_size --from-loop)
features=$(pos_get_variable input2_size --from-loop) || features=0
timerf="%M (Maximum resident set size in kbytes)\n%e (Elapsed wall clock time in seconds)\n%P (Percent of CPU this job got)\n%S (System time in seconds)"
player=$1
cdomain=$2
environ=""
read -r -a protocols <<< "$3"
# test types to simulate changing environments like cpu frequency or network latency
read -r -a types <<< "$4"
network="$5"
partysize="$6"
# experiment type to allow small differences in experiments
etype=$7
# default to etype 1 if unset
etype=${etype:-1}

cd "$REPO_DIR"

{
    echo "player: $player, cdomain: $cdomain, protocols: ${protocols[*]}, types: ${types[*]}"
    
    # MP-SPDZ specific part: compile experiment
    # only compile if not already compiled
    if [ $features -eq 0 ]; then
        binarypath="Programs/Bytecode/experiment-$size-$partysize-$etype-0.bc"
        if [ ! -f "$binarypath" ]; then
        case "$cdomain" in
            RING) 
                /bin/time -f "$timerf" ./compile.py -Z 3 -R 128 --budget 200000 experiment "$size" "$partysize" "$etype";;
            BINARY) 
                /bin/time -f "$timerf" ./compile.py -B 1 experiment "$size" "$partysize" "$etype";;
            *) # default to FIELD
                /bin/time -f "$timerf" ./compile.py -Y --budget 200000 experiment "$size" "$partysize" "$etype";;
        esac
        echo "$(du -BM "$binarypath" | cut -d 'M' -f 1) (Binary file size in MiB)"
        fi
    else
        binarypath="Programs/Bytecode/experiment-$size-$features-$partysize-$etype-0.bc"
        if [ ! -f "$binarypath" ]; then
        case "$cdomain" in
            RING) 
                /bin/time -f "$timerf" ./compile.py -Z 3 -R 128 experiment "$size" "$features" "$partysize" "$etype";;
            BINARY) 
                /bin/time -f "$timerf" ./compile.py -B 1 experiment "$size" "$features" "$partysize" "$etype";;
            *) # default to FIELD
                /bin/time -f "$timerf" ./compile.py -Y experiment "$size" "$features" "$partysize" "$etype";;
        esac
        echo "$(du -BM "$binarypath" | cut -d 'M' -f 1) (Binary file size in MiB)"
        fi
    fi
    
} |& tee measurementlog"$cdomain"

####
#  environment manipulation section start
####
# shellcheck source=../host_scripts/manipulate.sh
source "$REPO2_DIR"/host_scripts/manipulate.sh

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
                    setAllParameters "$partysize";;
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

for protocol in "${protocols[@]}"; do

    log=testresults"$cdomain""${protocol::-8}"
    touch "$log"

    success=true

    pos_sync --timeout 300

    # Some protocols are only for 2,3 or 4 parties
    # they imply the flag -N so it's not allowed
    extraflag="-N $partysize"
    # need to skip for some nodes
    skip=false
    if [[ " ${N4Protocols[*]} " == *" ${protocol::-8} "* ]]; then
        extraflag=""
        [ "$player" -lt 4 ] || skip=true
    elif [[ " ${N3Protocols[*]} " == *" ${protocol::-8} "* ]]; then
        extraflag=""
        [ "$player" -lt 3 ] || skip=true
    elif [[ " ${N2Protocols[*]} " == *" ${protocol::-8} "* ]]; then
        extraflag=""
        [ "$player" -lt 2 ] || skip=true
        # yao's -O protocol variant
        if [ "${protocol::-8}" == yaoO ]; then
            protocol=yao-party.x
            extraflag="-O"
        fi
        runflags="${runflags//-u/}"
    fi

    if [ $features -eq 0 ]; then
        $skip ||
        /bin/time -f "$timerf" ./"$protocol" $runflags -h 10.10."$network".2 $extraflag -p "$player" \
            experiment-"$size"-"$partysize"-"$etype" &> "$log" || success=false
    else
        $skip ||
        /bin/time -f "$timerf" ./"$protocol" $runflags -h 10.10."$network".2 $extraflag -p "$player" \
            experiment-"$size"-"$features"-"$partysize"-"$etype" &> "$log" || success=false
    fi
    # run the SMC protocol
    

    pos_upload --loop "$log"

    #abort if no success
    $success

    pos_sync

done

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

# if there are no test types
if [ "${#types[*]}" -lt 1 ]; then
    # older binaries won't be needed anymore and can be removed
    # this is important for a big number of various input sizes
    # as with many binaries a limited disk space gets consumed fast
    rm -rf Programs/Bytecode/*
fi

pos_sync --loop

echo "experiment successful"  >> measurementlog"$cdomain"

pos_upload --loop measurementlog"$cdomain"
