#!/bin/bash
# shellcheck disable=SC2154,2034

# where we find the experiment results
resultpath="$RPATH/${NODES[0]}/"

############
# Export experiment data from the pos_upload-ed logs into two tables
############
exportExperimentResults() {

    # set up location
    datatableShort="$EXPORTPATH/data/E${EXPERIMENT::2}_short_results.csv"
    datatableFull="$EXPORTPATH/data/E${EXPERIMENT::2}_full_results.csv"
    mkdir -p "$datatableShort"
    rm -rf "$datatableShort"

    dyncolumns=""
    # get the dynamic column names from the first .loop info file
    loopinfo=$(find "$resultpath" -name "*loop*" -print -quit)
    
    # check if loop file exists
    if [ -z "$loopinfo" ]; then
        okfail fail "nothing to export - no loop file found"
        return
    fi

    for columnname in $(jq -r 'keys_unsorted[]' "$loopinfo"); do
        dyncolumns+="$columnname"
        case "$columnname" in
            freqs) dyncolumns+="(GHz)";;
            quotas|packetdrops) dyncolumns+="(%)";;
            latencies) dyncolumns+="(ms)";;
            bandwidths) dyncolumns+="(Mbs)";;
        esac
        dyncolumns+=";"
    done

    # generate header line of data dump with column information
    basicInfo1="program;c.domain;adv.model;protocol;partysize;comp.time(s);comp.peakRAM(MiB);bin.filesize(MiB);"
    basicInfo2="${dyncolumns}runtime_internal(s);runtime_external(s);peakRAM(MiB);jobCPU(%);P0commRounds;P0dataSent(MB);ALLdataSent(MB);System time (s);Preprocessing Time(s)"
    compileInfo="comp.P0intin;comp.P1intin;comp.P2intin;comp.P0bitin;comp.P1bitin;compP2bitin;comp.intbits;comp.inttriples;comp.bittriples;comp.vmrounds;"
    echo -e "${basicInfo1}${basicInfo2}" > "$datatableShort"
    echo -e "${basicInfo1}${compileInfo}${basicInfo2};Tx(MB);Tx(rounds);Tx(s);Rx(MB);Rx(rounds);Rx(s);Brcasting(MB);Brcasting(rounds);Brcasting(s);TxRx(MB);TxRx(rounds);TxRx(s);Passing(MB);Passing(rounds);Passing(s);Part.Brcasting(MB);Part.Brcasting(rounds);Part.Brcasting(s);Ex(MB);Ex(rounds);Ex(s);Ex1to1(MB);Ex1to1(rounds);Ex1to1(s);Rx1to1(MB);Rx1to1(rounds);Rx1to1(s);Tx1to1(MB);Tx1to1(rounds);Tx1to1(s);Txtoall(MB);Txtoall(rounds);Txtoall(s)" > "$datatableFull"

    # grab all the measurement information and append it to the datatable
    for cdomain in "${CDOMAINS[@]}"; do
        declare -n cdProtocols="${cdomain}PROTOCOLS"
        for protocol in "${cdProtocols[@]}"; do
        protocol=${protocol::-8}

            advModel=""
            setAdvModel "$protocol"
            i=0
            # get loopfile path for the current variables
            loopinfo=$(find "$resultpath" -name "*$i.loop*" -print -quit)
            echo "  exporting $protocol"
            # while we find a next loop info file do
            while [ -n "$loopinfo" ]; do
                loopvalues="" 
                # extract loop var values
                for value in $(jq -r 'values[]' "$loopinfo"); do
                    loopvalues+="$value;"
                done

                # the actual number of participants
                partysize=""
                setPartySize "$protocol"
                
                # get pos filepath of the measurements for the current loop
                compileinfo=$(find "$resultpath" -name "measurementlog${cdomain}_run*$i" -print -quit)
                runtimeinfo=$(find "$resultpath" -name "testresults$cdomain${protocol}_run*$i" -print -quit)
                #If no loop is run, the file is named differently
                if [ ! -f "$runtimeinfo" ]; then
                runtimeinfo=$(find "$resultpath" -name "testresults$cdomain${protocol}" -print -quit)
                fi
                if [ ! -f "$runtimeinfo" ] || [ ! -f "$compileinfo" ]; then
                    styleOrange "    Skip - File not found error: runtimeinfo or compileinfo"
                    continue 2
                fi

                ## Minimum result measurement information
                ######
                # extract measurement
                compiletime=$(grep "Elapsed wall" "$compileinfo" | tail -n 1 | cut -d ' ' -f 1)
                compilemaxRAMused=$(grep "Maximum resident" "$compileinfo" | tail -n 1 | cut -d ' ' -f 1)
                binfsize=$(grep "Binary file size" "$compileinfo" | tail -n 1 | cut -d ' ' -f 1)
                [ -n "$compilemaxRAMused" ] && compilemaxRAMused="$((compilemaxRAMused/1024))"
                runtimeint=$(grep "Time =" "$runtimeinfo" | awk '{print $3}')
                runtimeext=$(grep "Elapsed wall" "$runtimeinfo" | tail -n 1 | cut -d ' ' -f 1)
                maxRAMused=$(grep "Maximum resident" "$runtimeinfo" | tail -n 1 | cut -d ' ' -f 1 )
                systime=$(grep "System time" "$runtimeinfo" | tail -n 1 | cut -d ' ' -f 1 )
                [ -n "$maxRAMused" ] && maxRAMused="$((maxRAMused/1024))"
                jobCPU=$(grep "CPU this job" "$runtimeinfo" | awk '{print $1}')
                maxRAMused=${maxRAMused:-NA}
                compilemaxRAMused=${compilemaxRAMused:-NA}
                preprocessing=$(grep "preprocessing/offline" "$runtimeinfo" | awk '{print $13}')
                commRounds=$(grep "Data sent =" "$runtimeinfo" | awk '{print $7}')
                dataSent=$(grep "Data sent =" "$runtimeinfo" | awk '{print $4}')
                globaldataSent=$(grep "Global data sent =" "$runtimeinfo" | awk '{print $5}')
                basicComm="${commRounds:-NA};${dataSent:-NA};${globaldataSent:-NA}"

                # put all collected info into one row (Short)
                basicInfo="${EXPERIMENT::2};$cdomain;$advModel;$protocol;$partysize;${compiletime:-NA};$compilemaxRAMused;${binfsize:-NA}"
                echo -e "$basicInfo;$loopvalues$runtimeint;$runtimeext;$maxRAMused;$jobCPU;$basicComm;$systime;${preprocessing:-NA}" >> "$datatableShort"

                ## Full result measurement information
                ######
                # extract compile information (this is repeated many times, potential to optimize)
                p0intin=$(grep " integer inputs from player 0" "$compileinfo" | awk '{print $1}')
                p1intin=$(grep " integer inputs from player 1" "$compileinfo" | awk '{print $1}')
                p2intin=$(grep " integer inputs from player 2" "$compileinfo" | awk '{print $1}')
                p0bitin=$(grep " bit inputs from player 0" "$compileinfo" | awk '{print $1}')
                p1bitin=$(grep " bit inputs from player 1" "$compileinfo" | awk '{print $1}')
                p2bitin=$(grep " bit inputs from player 2" "$compileinfo" | awk '{print $1}')
                inputs="${p0intin:-NA};${p1intin:-NA};${p2intin:-NA};${p0bitin:-NA};${p1bitin:-NA};${p2bitin:-NA}"

                intbits=$(grep " integer bits" "$compileinfo" | awk '{print $1}')
                inttriples=$(grep " integer triples" "$compileinfo" | awk '{print $1}')
                bittriples=$(grep " bit triples" "$compileinfo" | awk '{print $1}')
                vmrounds=$(grep " virtual machine rounds" "$compileinfo" | awk '{print $1}')

                compilevalues="$inputs;${intbits:-NA};${inttriples:-NA};${bittriples:-NA};${vmrounds:-NA}"

                declare {Tx,Rx,broadcast,TxRx,passing,partBroadcast,Ex,Ex1to1,Rx1to1,Tx1to1,Txtoall}=""
                # infolineparser $1=regex $2=var-reference $3=column1 $4=column2 $5=column3
                infolineparser "Sending directly " "Tx" 3 6 9
                infolineparser "Receiving directly " "Rx" 3 6 9
                infolineparser "Broadcasting " "broadcast" 2 5 8
                infolineparser "Sending/receiving " "TxRx" 2 5 8
                infolineparser "Passing around " "passing" 3 6 9
                infolineparser "Partial broadcasting " "partBroadcast" 3 6 9
                infolineparser "Exchanging " "Ex" 2 5 8
                infolineparser "Exchanging one-to-one " "Ex1to1" 3 6 9
                infolineparser "Receiving one-to-one " "Rx1to1" 3 6 9
                infolineparser "Sending one-to-one " "Tx1to1" 3 6 9
                infolineparser "Sending to all " "Txtoall" 4 7 10

                measurementvalues="$runtimeint;$runtimeext;$maxRAMused;$jobCPU;$basicComm;$Tx;$Rx;$broadcast;$TxRx;$passing;$partBroadcast;$Ex;$Ex1to1;$Rx1to1;$Tx1to1;$Txtoall"

                # put all collected info into one row (Full)
                echo -e "$basicInfo;$compilevalues;$loopvalues$measurementvalues" >> "$datatableFull"

                # locate next loop file
                ((++i))
                loopinfo=$(find "$resultpath" -name "*$i.loop*" -print -quit)
            done
        done
    done
    # check if there was something exported
    rowcount=$(wc -l "$datatableShort" | awk '{print $1}')
    if [ "$rowcount" -lt 2 ];then
        okfail fail "nothing to export"
        rm "$datatableShort"
        return
    fi

    # create a tab separated table for pretty formating
    # convert .csv -> .tsv
    column -s ';' -t "$datatableShort" > "${datatableShort::-3}"tsv
    column -s ';' -t "$datatableFull" > "${datatableFull::-3}"tsv
    okfail ok "exported short and full results (${datatableShort::-3}tsv)"

    # Add speedtest infos to summaryfile
    {
        echo -e "\n\nNetworking Information"
        echo "Speedtest Info"
        # get speedtest results
        for node in "${NODES[@]}"; do
            grep -hE "measured speed|Threads|total" "$RPATH/$node"/speedtest 
        done
        # get pingtest results
        echo -e "\nLatency Info"
        for node in "${NODES[@]}"; do
            echo "Node $node statistics"
            grep -hE "statistics|rtt" "$RPATH/$node"/pinglog
        done
    } >> "$SUMMARYFILE"

    # push to measurement data git
    repourl=$(grep "repoupload" global-variables.yml | cut -d ':' -f 2-)
    # check if upload git does not exist yet
    if [ ! -d git-upload/.git ]; then
        # clone the upload git repo
        # default to trust server fingerprint authenticity (usually insecure)
        GIT_SSH_COMMAND='ssh -o StrictHostKeyChecking=accept-new' git clone "${repourl// /}" git-upload
    fi

    echo " pushing experiment measurement data to git repo$repourl"
    cd git-upload || { warning "${FUNCNAME[0]}:${LINENO} cd into gitrepo failed"; return; }
    {
        # a pull is not really required, but for small sizes it doesn't hurt
        git pull
        # copy from local folder to git repo folder
        [ ! -d "$EXPORTPATH" ] && mkdir -p "$EXPORTPATH"
        cp -r ../"$EXPORTPATH" "${EXPORTPATH::-11}"
        git add . 
        git commit -a -m "script upload"
        git push 
    } &> /dev/null ||{ warning "${FUNCNAME[0]}:${LINENO} git upload failed"; return; }
        okfail ok " upload success" 
}

infolineparser() {
    # infolineparser $1=regex $2=var-reference $3=column1 $4=column2 $5=column3
    regex="$1"
    # get reference
    declare -n target="$2"

    MB=$(grep "$regex" "$runtimeinfo" | head -n 1 | cut -d ' ' -f "$3")
    Rounds=$(grep "$regex" "$runtimeinfo" | head -n 1 | cut -d ' ' -f "$4")
    Sec=$(grep "$regex" "$runtimeinfo" | head -n 1 | cut -d ' ' -f "$5")
    target="${MB:-NA};${Rounds:-NA};${Sec:-NA}"
}

# find out and set a protocols adversary model
setAdvModel() {
    protocol="$1"
    if [[ " ${maldishonestProtocols[*]} " == *" $protocol "* ]]; then
        advModel=maldishonest
    elif [[ " ${covertdishonestProtocols[*]} " == *" $protocol "* ]]; then
        advModel=covertdishonest
    elif [[ " ${semidishonestProtocols[*]} " == *" $protocol "* ]]; then
        advModel=semidishonest
    elif [[ " ${malhonestProtocols[*]} " == *" $protocol "* ]]; then
        advModel=malhonest
    elif [[ " ${semihonestProtocols[*]} " == *" $protocol "* ]]; then
        advModel=semihonest
    fi
}

# find out the actual party size, the nodecount does not imply the size
# since the program only uses as many nodes needed from all available
setPartySize() {

    protocol="$1"
    nodecount="${#NODES[*]}"
    partysize=""

    if [[ " ${N4Protocols[*]} " == *" $protocol "* ]]; then
        partysize="4"
    elif [[ " ${N3Protocols[*]} " == *" $protocol "* ]]; then
        partysize="3"
    elif [[ " ${N2Protocols[*]} " == *" $protocol "* ]]; then
        partysize="2"
    fi

    partysize=${partysize:-$nodecount}

}