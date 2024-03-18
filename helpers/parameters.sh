#!/bin/bash
# shellcheck disable=SC2034,2154

###
# This script handles the parameter read in of the benchmarking tool
# As parameters vary between the different frameworks, this is somewhat framework dependent.
# Most provided paramaters are however framework independent, such as the input size, the network and system parameter and certain output options.
# It can easily be updated to read in additional parameters
# Additionally it provides functionality to read in a config style 
#instead of providing command line parameters and even entire config folder.


usage() {
    styleCyan "$0: $1"
    echo
    echo "Options: { -e[xperiment] | -n[odes] | -p[rotocols] | -i[nput] | -c[pu] |"
    echo "           -q(--cpuquota) | -f[req] | -r[am] | -l[atency] | -b(andwidth)} |"
    echo "           -d(--packetdrop)"
    echo -e "\nRun '$0 --help' for more information.\n"
    echo "Available experiments:"
	ls experiments
    echo -e "\nAvailable NODES:"
	# xargs replaces '\n' with ' '
	pos no li | grep -E "$(whoami)|None" | awk '{print $1}' | xargs
    exit 1
}

help() {
	echo "$0 - run SMC experiments with POS testbed environment"
    echo "Example:  ./$0 -f mp-spdz -e 31_scalable_search -p shamir,atlas -n valga,tapa,rapla -i 10,20,...,100 -q 20,40,80 -f 1.9,2.6"
    echo
    echo "<Values> supported are of the form <value1>[,<value2>,...] or use \"...\" to specify the range"
    echo "       [...,<valuei>,]<start>,<next>,...,<stop>[,valuek,...], with increment steps <next>-<start>"
    echo -e "\nOptions (mandatory)"
    echo "-f, --framework     framework to run"
    echo " -e, --experiment     experiment to run"
    echo " -n, --nodes          nodes to run the experiment on of the form <node1>[,<node2>,...]"
    echo -e "\nOptions (optional)"
    echo "     --config         config files run with <path> as parameter, nodes can be given separatly"
    echo "                      allowed form: $0 --config file.conf [nodeA,...]"
    echo -e "\nManipulate Host Environment (optional)"
    echo " -c, --cpu            cpu thread counts, with <Values>"
    echo " -q, --cpuquota       cpu quotas in % (10 < quota), with <Values>"
    echo "  --freq           cpu frequencies in GHz (e.g. 1.7), with <Values>"
    echo " -r, --ram            limit max RAM in MiB (e.g. 1024), with <Values>, /dev/nvme0n1 required"
    echo "     --swap           set secondary memory swap size in MiB, one value, SSD /dev/nvme0n1 required"
    echo "                      mandatory with -r to allow paging/swaping (default 4096)"
    echo "                      Warning: setting this too small will break the entire run at some point"
    echo -e "\nManipulate Network Environment (optional)"
    echo " -l, --latency        latency of network in ms, with <Values>"
    echo " -b, --bandwidth      bandwidth of network in MBit/s, with <Values>"
    echo " -d, --packetdrop     packet drop/loss in network in %, with <Values>"
	echo -e "\nAvailable experiments:\n"
	ls experiments
	echo -e "\nAvailable NODES:\n"
	# xargs replaces '\n' with ' '
	pos no li | grep -E "$(whoami)|None" | awk '{print $1}' | xargs
	exit 0
}

setArray() { # load array $1 reference with ,-seperated values in $2
    local -n array="$1"     # get array reference
    set -f                  # avoid * expansion
    IFS="," read -r -a array <<< "$2"
    for element in "${array[@]}"; do
        echo "$element"
    done
}

TEMPFILES=()
ALLOC_ID=""
EXPORTPATH="results/$(date +20%y-%m)/$(date +%d_%H-%M-%S)"
# pos_upload resultspath
RPATH=""
SUMMARYFILE=""
POS=pos
IMAGE=debian-bullseye
SECONDS=0
RUNSTATUS="${Red}fail${Stop}"
# this is required for the config support logic
CONFIGRUN=false
#MP-SPDZ
ETYPE=""
compflags=""
progflags=""
runflags=""
PROTOCOLS=()
CDOMAINS=()
FIELDPROTOCOLS=()
RINGPROTOCOLS=()
BINARYPROTOCOLS=()

#HPMPC
# MP slice vars with default values
DATATYPE=( 64 )
PROTOCOL=( 2 )
PREPROCESS=( 0 )
SPLITROLES=( 0 )
PACKBOOL=( 0 )
OPTSHARE=( 1 )
SSL=( 1 )
THREADS=( 1 )
FUNCTION=( 0 )
TXBUFFER=( 0 )
RXBUFFER=( 0 )
VERIFYBUFFER=( 0 )
manipulate="6666"

FRAMEWORK=""
EXPERIMENT=""
NODES=()
INPUTS=()
INPUT2=()
CPUS=()
QUOTAS=()
FREQS=()
LATENCIES=()
BANDWIDTHS=()
PACKETDROPS=()
RAM=()
SWAP=""
TTYPES=()
PIDS=()
# create a random network number to support multiple experiment runs 
# on the same switch.   Generate random number  1 < number < 255
NETWORK=$((RANDOM%253+2))



# Parsing inspired from https://stackoverflow.com/a/29754866
# https://gist.github.com/74e9875d5ab0a2bc1010447f1bee5d0a

setParameters() {
    echo "Start"
    # verify if getopt is available
    getopt --test > /dev/null
    [ $? -ne 4 ] && { error $LINENO "${FUNCNAME[0]}(): getopt not available 
        for parsing arguments."; }
    # define the flags for the parameters
    # ':' means that the flag expects an argument.
    SHORT=n:,e:,i:,m:,c:,q:,f:,r:,l:,b:,d:,x,h
    LONG=nodes:,protocols:,framework:,dtype:,preproc:,maldishonest,codishonest,semidishonest,malhonest,semihonest,field,ring,binary,all,experiment:,etype:,compflags:,progflags:,runflags:,input:,input2:,config:,measureram:,cpu:,cpuquota:,freq:,latency:,bandwidth:,packetdrop:,help 
    LONG+=,split:,packbool:,optshare:,ssl:,threads:,manipulate:,function:
    LONG+=,txbuffer:,rxbuffer:,verifybuffer:
    PARSED=$(getopt --options ${SHORT} \
                    --longoptions ${LONG} \
                    --name "$0" \
                    -- "$@") || { error $LINENO "${FUNCNAME[0]}(): getopt failed parsing options"; }

    eval set -- "${PARSED}"
    while [ $# -gt 1 ]; do
        #echo "parsing arg: $1 $2"
        case "$1" in
            -h|--help)
                help;;
            -f|--framework)
                FRAMEWORK="$2"
                shift;;
            -n|--nodes) 
                setArray NODES "$2"
                shift;;
            -i|--input)
                setArray INPUTS "$2"
                shift;;
            --input2)
                setArray PARAM2 "$2"
                shift;;
            -e|--experiment)
                EXPERIMENT="$2"
                shift;;
            -m|--measureram)
                TTYPES+=( MEASURERAM );;
            # MP-Slice args
            --dtype)
                setArray DATATYPE "$2"
                shift;;
            --preproc)
                setArray PREPROCESS "$2"
                shift;;
            --split)
                setArray SPLITROLES "$2"
                shift;;
            --packbool)
                setArray PACKBOOL "$2"
                shift;;
            --optshare)
                setArray OPTSHARE "$2"
                shift;;
            --ssl)
                setArray SSL "$2"
                shift;; 
            --threads)
                setArray THREADS "$2"
                shift;;
            --function)
                setArray FUNCTION "$2"
                shift;;
            --txbuffer)
                setArray TXBUFFER "$2"
                shift;;
            --rxbuffer)
                setArray RXBUFFER "$2"
                shift;;
            --verifybuffer)
                setArray VERIFYBUFFER "$2"
                shift;;
            --manipulate)
                manipulate="$2"
                shift;;
            # Host environment manipulation
            -c|--cpu)
                TTYPES+=( CPUS )
                setArray CPUS "$2"
                shift;;
            -q|--cpuquota)
                TTYPES+=( QUOTAS )
                setArray QUOTAS "$2"
                shift;;
            --freq)
                TTYPES+=( FREQS )
                setArray FREQS "$2"
                shift;;
            -r|--ram)
                TTYPES+=( RAM )
                setArray RAM "$2"
                shift;;
            # Network environment manipulation
            -l|--latency)
                TTYPES+=( LATENCIES )
                setArray LATENCIES "$2"
                shift;;
            -b|--bandwidth)
                TTYPES+=( BANDWIDTHS )
                setArray BANDWIDTHS "$2"
                shift;;
            -d|--packetdrop)
                TTYPES+=( PACKETDROPS )
                setArray PACKETDROPS "$2"
                shift;;
            -p|--protocols) 
                setArray PROTOCOLS "$2"
                shift;;
            #MP-SPDZ Args
            --etype)
                ETYPE="$2"
                shift;;
            --compflags)
                compflags="$2"
                shift;;
            --progflags)
                progflags="$2"
                shift;;
            --runflags)
                runflags="$2"
                shift;;
            --maldishonest)
                PROTOCOLS+=( "${maldishonestProtocols[@]}" );;
            --codishonest)
                PROTOCOLS+=( "${covertdishonestProtocols[@]}" );;
            --semidishonest)
                PROTOCOLS+=( "${semidishonestProtocols[@]}" );;
            --malhonest)
                PROTOCOLS+=( "${malhonestProtocols[@]}" );;
            --semihonest)
                PROTOCOLS+=( "${semihonestProtocols[@]}" );;
            --field)
                PROTOCOLS+=( "${supportedFieldProtocols[@]}" );;
            --ring)
                PROTOCOLS+=( "${supportedRingProtocols[@]}" );;
            --binary)
                PROTOCOLS+=( "${supportedBinaryProtocols[@]}" );;
            --all)
                # remove real-bmr for explosive runtime costs, need to specify explicitly
                PROTOCOLS=( "${supportedFieldProtocols[@]}" "${supportedRingProtocols[@]}" "${supportedBinaryProtocols[@]//real-bmr/}");;
            --swap)
                SWAP="$2"
                shift;;
            -x)
                CONFIGRUN=true;;
            --config)
                parseConfig "$2" "$4"
                exit 0;;
            *) error $LINENO "${FUNCNAME[0]}(): unrecognized flag $1 $2";;
        esac
        shift || true      # skip to next option-argument pair
    done
    EXPORTPATH="results/$FRAMEWORK/$(date +20%y-%m)/$(date +%d_%H-%M-%S)"
    
    # node already in use check
    #nodetasks=$(pgrep -facu "$(id -u)" "${NODES[0]}")
    #[ "$nodetasks" -gt 10 ] && error $LINENO "${FUNCNAME[0]}(): it appears host ${NODES[0]} is currently in use"

     # generate loop-variables.yml (append random num to mitigate conflicts)
    loopvarpath="experiments/loop-variables-$NETWORK.yml"
    rm -f "$loopvarpath"
    for type in "${TTYPES[@]}"; do
        declare -n ttypes="${type}"
        parameters="${ttypes[*]}"
        echo "${type,,}: [${parameters// /, }]" >> "$loopvarpath"
    done
    
    parameters="${INPUTS[*]}"
    echo "input_size: [${parameters// /, }]" >> "$loopvarpath"
    if [ "${#INPUT2[*]}" -gt 0 ]; then
        parameters="${INPUT2[*]}"
        echo "input2_size: [${parameters// /, }]" >> "$loopvarpath"
    fi


    # delete line measureram from loop_var, if active
    sed -i '/measureram/d' "$loopvarpath"
    # set default swap size, in case --ram is defined
    [ "${#RAM[*]}" -gt 0 ] && SWAP=${SWAP:-4096}


    # Check if framework is mpspdz
    if [ "$FRAMEWORK" == "mp-spdz" ]; then
         # valid experiment checkvi
        if [ -f experiments/"$FRAMEWORK"/"$EXPERIMENT"/parameters.yml ]; then
        # get experiment node count from experiment parameters file
        requiredNODES=$(grep node_count experiments/"$FRAMEWORK"/"$EXPERIMENT"/parameters.yml | awk '{print $2}')
        # check if the value node_count exists
        [ "$requiredNODES" -lt 1 ] && requiredNODES="-1"
        else
        usage "Experiment $EXPERIMENT/parameters.yml not found"
        fi
        protocolcount="${#PROTOCOLS[*]}"
        [ "$protocolcount" -lt 1 ] && usage "no protocols specified"
        echo "Framework is mpspdz"
        # add extra flags to parameters yaml
        parapath=experiments/"$FRAMEWORK"/"$EXPERIMENT"/parameters.yml

        # first, delete old flags
        grep -Ev "compflags|progflags|runflags" "$parapath" > tmp$NETWORK
        cat tmp$NETWORK > "$parapath"
        rm "tmp$NETWORK"

        if [ -n "$compflags" ]; then
            echo -e "\ncompflags: $compflags" >> "$parapath"
        else
            echo -e "\ncompflags: " >> "$parapath"
        fi

        if [ -n "$progflags" ]; then
            echo -e "\nprogflags: $progflags" >> "$parapath"
        else
            echo -e "\nprogflags: " >> "$parapath"
        fi

        if [ -n "$runflags" ]; then
            echo -e "\nrunflags: $runflags" >> "$parapath"
        else
            echo -e "\nrunflags: " >> "$parapath"
        fi

        # split up protocols to computation domains
        for protocol in "${PROTOCOLS[@]}"; do
            if [[ " ${supportedFieldProtocols[*]} " == *" $protocol "* ]]; then
                # filter duplicats
                [[ " ${FIELDPROTOCOLS[*]} " == *" $protocol "* ]] || FIELDPROTOCOLS+=( "$protocol" )
            elif [[ " ${supportedRingProtocols[*]} " == *" $protocol "* ]]; then
                [[ " ${RINGPROTOCOLS[*]} " == *" $protocol "* ]] || RINGPROTOCOLS+=( "$protocol" )
            elif [[ " ${supportedBinaryProtocols[*]} " == *" $protocol "* ]]; then
                [[ " ${BINARYPROTOCOLS[*]} " == *" $protocol "* ]] || BINARYPROTOCOLS+=( "$protocol" )
            else
                warning "protocol $protocol was not found, skipping"
            fi
        done

        # activate computation domain for later handling
        [ "${#FIELDPROTOCOLS[*]}" -gt 0 ] && CDOMAINS+=( FIELD )
        [ "${#RINGPROTOCOLS[*]}" -gt 0 ] && CDOMAINS+=( RING )
        [ "${#BINARYPROTOCOLS[*]}" -gt 0 ] && CDOMAINS+=( BINARY )

        # append -party.x to all protocols
        for cdomain in "${CDOMAINS[@]}"; do
            declare -n protos="${cdomain}PROTOCOLS"
            protos=( "${protos[@]/%/-party.x}" )
        done
        PROTOCOLS=( "${FIELDPROTOCOLS[@]}" "${RINGPROTOCOLS[@]}" "${BINARYPROTOCOLS[@]}" )
        
        

        # Experiment run summary  information output
        SUMMARYFILE="$EXPORTPATH/E${EXPERIMENT::2}-run-summary.dat"
        mkdir -p "$SUMMARYFILE" && rm -rf "$SUMMARYFILE"
        {
            echo "  Setup:"
            echo "    Experiment = $EXPERIMENT $ETYPE"
            echo "    Nodes = ${NODES[*]}"
            echo "    Internal network = 10.10.$NETWORK.0/24"
            echo "    Protocols:"
            echo "      Field  = ${FIELDPROTOCOLS[*]/-party.x/}"
            echo "      Ring   = ${RINGPROTOCOLS[*]/-party.x/}"
            echo "      Binary = ${BINARYPROTOCOLS[*]/-party.x/}"
            echo "    Inputs = ${INPUTS[*]}"
            echo "    Compile flags: $compflags"
            echo "    Program flags: $progflags"
            echo "    Run flags: $runflags"
            echo "    Testtypes:"
            for type in "${TTYPES[@]}"; do
                declare -n ttypes="${type}"
                echo -e "      $type\t= ${ttypes[*]}"
            done
            echo "  Summary file = $SUMMARYFILE"
        } | tee "$SUMMARYFILE"

    elif [ "$FRAMEWORK" == "mpyc" ]; then
        # Experiment run summary  information output
        SUMMARYFILE="$EXPORTPATH/run-summary.dat"
        mkdir -p "$EXPORTPATH" && rm -rf "$SUMMARYFILE"
        {
        echo "  Setup:"
        echo "    Experiment = $EXPERIMENT $ETYPE"
        echo "    Nodes = ${NODES[*]}"
        echo "    Internal network = 10.10.$NETWORK.0/24"
        echo "    Testtypes:"
        for type in "${TTYPES[@]}"; do
            declare -n ttypes="${type}"
            echo -e "      $type\t= ${ttypes[*]}"
        done
        echo "  Summary file = $SUMMARYFILE"
        } | tee "$SUMMARYFILE"
    elif [ "$FRAMEWORK" == "motion" ]; then
        # split up protocols to computation domains
        for protocol in "${PROTOCOLS[@]}"; do
            if [[ "arithmetic_gmw" == "$protocol" ]]; then
                echo "arithmetic_gmw"
            elif [[ "boolean_bmr" == "$protocol" ]]; then
                echo "boolean_bmr"
            elif [[ "boolean_gmw" == "$protocol" ]]; then
                echo "boolean_gmw"
            else
                error $LINENO "${FUNCNAME[0]}(): protocol $protocol not supported"
            fi
        done
        # Experiment run summary  information output
        SUMMARYFILE="$EXPORTPATH/${EXPERIMENT}_run-summary.dat"
        mkdir -p "$EXPORTPATH" && rm -rf "$SUMMARYFILE"
        {
        echo "  Setup:"
        echo "    Experiment = $EXPERIMENT $ETYPE"
        echo "    Nodes = ${NODES[*]}"
        echo "    Internal network = 10.10.$NETWORK.0/24"
        echo "    Inputs = ${INPUTS[*]}"
        echo "    Protocols = ${PROTOCOLS[*]}"
        echo "    Testtypes:"
        
        for type in "${TTYPES[@]}"; do
            declare -n ttypes="${type}"
            echo -e "      $type\t= ${ttypes[*]}"
        done
        echo "  Summary file = $SUMMARYFILE"
        } | tee "$SUMMARYFILE"
    elif [ "$FRAMEWORK" == "hpmpc" ]; then
        echo "hpmpc detected"
        # set experiment wide variables (append random num to mitigate conflicts)
        # if value may contain a leading 0 (zero), add any char before (like manipulate)
        # Config Vars
        Protocol=${PROTOCOLS[*]}
        configvars=( OPTSHARE PACKBOOL SPLITROLES PROTOCOL PREPROCESS DATATYPE )
        configvars+=( SSL THREADS FUNCTION TXBUFFER RXBUFFER VERIFYBUFFER)
        for type in "${configvars[@]}"; do
            declare -n ttypes="${type}"
            parameters="${ttypes[*]}"
            echo "${type,,}: [${parameters// /, }]" >> "$loopvarpath"
        done
        # Experiment run summary information output
        SUMMARYFILE="$EXPORTPATH/Eslice-run-summary.dat"
        mkdir -p "$SUMMARYFILE" && rm -rf "$SUMMARYFILE"
        {
            echo "  Setup:"
            echo "    Experiment = $EXPERIMENT $ETYPE"
            echo "    Nodes = ${NODES[*]}"
            echo "    Internal network = 10.10.$NETWORK.0/24"
            echo "    Function: ${FUNCTION[*]}"
            echo "    Protocols: ${PROTOCOL[*]}"
            echo "    Datatypes = ${DATATYPE[*]}"
            echo "    Inputs = ${INPUTS[*]}"
            echo "    Preprocessing: ${PREPROCESS[*]}"
            echo "    SplitRoles: ${SPLITROLES[*]}"
            echo "    Pack Bool: ${PACKBOOL[*]}"
            echo "    Optimized Sharing: ${OPTSHARE[*]}"
            echo "    SSL: ${SSL[*]}"
            echo "    Threads: ${THREADS[*]}"
            echo "    txBuffer: ${TXBUFFER[*]}"
            echo "    rxBuffer: ${RXBUFFER[*]}"
            echo "    verifyBuffer: ${VERIFYBUFFER[*]}"
            [ "$manipulate" != "6666" ] && echo "    manipulate: $manipulate"
            echo "    Testtypes:"
            for type in "${TTYPES[@]}"; do
                declare -n ttypes="${type}"
                echo -e "      $type\t= ${ttypes[*]}"
            done
            echo "  Summary file = $SUMMARYFILE"
            } | tee "$SUMMARYFILE"
    fi
    
}

# inspired by https://unix.stackexchange.com/a/206216
parseConfig() {

    # overwrite the main trap
    trap configruntrap 0

    configs=()
    # file or folder?
    if [ -f "$1" ]; then
        configs=( "$1" )
    elif [ -d "$1" ]; then
        # add all config files in the folder to the queue 
        while IFS= read -r conf; do
            configs+=( "$conf" )
        done < <(find "$1" -maxdepth 1 -name "*.conf" | sort)
    else
        error ${LINENO} "${FUNCNAME[0]}(): no such file or directory: $1"
    fi

    for conf in "${configs[@]}"; do

        echo -e "\n_____________________________________"
        echo "###   Starting new config file \"$conf\" ###"
        echo -e "_____________________________________\n"

        declare -A config=()
        while read -r line; do
            # skip # lines
            [[ "${line::4}" == *"#"* ]] && continue
            # sanitize a little by removing everything after any space char
            sanline="${line%% *}"

            flag=$(echo "$sanline" | cut -d '=' -f 1)
            parameter=$(echo "$sanline" | cut -d '=' -f 2-)
            [ -n "$parameter" ] && config[$flag]="$parameter"
            # for flags without parameter, cut returns the flag
            [ "$flag" == "$parameter" ] && config[$flag]=""
        done < "$conf"

        # also allow specifying the nodes via commandline in the form
        # ./sevarebench.sh --config xy.conf nodeA,nodeB,...
        [ -z "${config[nodes]}" ] && config[nodes]="$2"
        # override mode for externally defined nodes
        #[ -n "$2" ] && config[nodes]="$2"

        while read -rd , experiment; do

            echo -e "\n_____________________________________"
            echo "###   Starting new experiment run ###"
            echo -e "_____________________________________\n"
            # generate the specifications
            flagsnparas=( --experiment "$experiment" )
            for flag in "${!config[@]}"; do
                # skip experiment flag
                [ "$flag" != experiments ] && flagsnparas=( "${flagsnparas[@]}" --"$flag" "${config[$flag]}" )
            done
            echo "running \"bash $0 ${flagsnparas[*]}\""

            # run a new instance of sevarebench with the parsed parameters
            # internal flag -x prevents the recursive closing of the process
            # group in the trap logic that would also close this instance
            bash "$0" -x "${flagsnparas[@]}" || 
                error ${LINENO} "${FUNCNAME[0]}(): stopping config run due to an error"
                
        done <<< "${config[experiments]}",

    done
}