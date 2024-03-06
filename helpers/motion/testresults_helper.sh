#!/bin/bash
# shellcheck disable=SC2154,2034

# where we find the experiment results
resultpath="$RPATH/${NODES[0]}/"

############
# Export experiment data from the pos_upload-ed logs into two tables
############

exportExperimentResults() {

    # set up location
    datatableShort="$EXPORTPATH/data/short_results.csv"
    datatableFull="$EXPORTPATH/data/full_results.csv"
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
    basicInfo1="program;protocol;partysize"
    basicInfo2="${dyncolumns}runtime_internal(ms);runtime_external(s);peakRAM(MiB);jobCPU(%);ALLdataSent(MB);AllDataRec(MB);ALLmessagesSent;AllMessagesRec"
    echo -e "$basicInfo1;$basicInfo2" >> "$datatableShort"
    echo -e "$basicInfo1;$basicInfo2;multTripPresetup;multTripSetup;sharedPowerPresetup;sharedPowerSetup;sharedBitPresetup;sharedBitSetup;baseOT;otExtension;kk13OtExtension;preprocessingTime;gatesSetup;gatesOnline" >> "$datatableFull"
    # grab all the measurement information and append it to the datatable
   
    for protocol in "${PROTOCOLS[@]}"; do

    i=0
    # get loopfile path for the current variables
    if [ "$i" -lt 10 ]; then
    loopinfo=$(find "$resultpath" -name "*0$i.loop*" -print -quit)
    else
    loopinfo=$(find "$resultpath" -name "*$i.loop*" -print -quit)
    fi

    echo "  exporting $protocol"
    # while we find a next loop info file do
    while [ -n "$loopinfo" ]; do
        loopvalues=""
        # extract loop var values
        for value in $(jq -r 'values[]' "$loopinfo"); do
            loopvalues+="$value;"
        done

        # the actual number of participants
        partysize=${#NODES[*]}
        
        # get pos filepath of the measurements for the current loop
        if [ "$i" -lt 10 ]; then
    runtimeinfo=$(find "$resultpath" -name "testresults${protocol}*_run0$i" -print -quit)
    else
    runtimeinfo=$(find "$resultpath" -name "testresults${protocol}*_run*$i" -print -quit)
    fi
        
        if [ ! -f "$runtimeinfo" ]; then
            styleOrange "    Skip - File not found error: runtimeinfo or compileinfo"
            continue 2
        fi

        ## Minimum result measurement information
        ######
        # extract measurement
        runtimeint=$(grep "Circuit Evaluation" "$runtimeinfo" | awk '{print $3}')
        runtimeext=$(grep "Elapsed wall clock time" "$runtimeinfo" | cut -d ' ' -f 1)
        maxRAMused=$(grep "Maximum resident" "$runtimeinfo" | cut -d ' ' -f 1)
        [ -n "$maxRAMused" ] && maxRAMused="$((maxRAMused/1024))"
        jobCPU=$(grep "CPU this job" "$runtimeinfo" | cut -d '%' -f 1)
        maxRAMused=${maxRAMused:-NA}

        dataSent=$(grep "Sent:" "$runtimeinfo" | awk '{print $2}')
        dataRec=$(grep "Received:" "$runtimeinfo" | awk '{print $2}')
        basicComm="${dataRec:-NA};${dataSent:-NA}"
        messagesSent=$(grep "Sent:" "$runtimeinfo" | awk '{print $5}')
        messagesRec=$(grep "Received:" "$runtimeinfo" | awk '{print $5}')
        basicMes="${messagesRec:-NA};${messagesSent:-NA}"

        # put all collected info into one row (Short)
        basicInfo="$EXPERIMENT;$protocol;$partysize"
        echo -e "$basicInfo;$loopvalues$runtimeint;$runtimeext;$maxRAMused;$jobCPU;$basicComm;$basicMes" >> "$datatableShort"

        ## Full result measurement information
        ######
        multTripPresetup=$(grep "MT Presetup" "$runtimeinfo" | awk '{print $3}')
        multTripSetup=$(grep "MT Setup" "$runtimeinfo" | awk '{print $3}')
        sharedPowerPresetup=$(grep "SP Presetup" "$runtimeinfo" | awk '{print $3}')
        sharedPowerSetup=$(grep "SP Presetup" "$runtimeinfo" | awk '{print $3}')
        sharedBitPresetup=$(grep "SB Setup" "$runtimeinfo" | awk '{print $3}')
        sharedBitSetup=$(grep "SB Setup" "$runtimeinfo" | awk '{print $3}')
        baseOT=$(grep "Base OTs" "$runtimeinfo" | awk '{print $3}')
        otExtension=$(grep -m 1 "OT Extension Setup" "$runtimeinfo" | awk '{print $3}')
        kk13OtExtension=$(grep "KK13 OT Extension Setup" "$runtimeinfo" | awk '{print $3}')
        preprocessingTime=$(grep "Preprocessing Total" "$runtimeinfo" | awk '{print $3}')
        gatesSetup=$(grep "Gates Setup" "$runtimeinfo" | awk '{print $3}')
        gatesOnline=$(grep "Gates Online" "$runtimeinfo" | awk '{print $3}')

        measurementvalues="$multTripPresetup;$multTripSetup;$sharedPowerPresetup;$sharedPowerSetup;$sharedBitPresetup;$sharedBitSetup;$baseOT;$otExtension;$kk13OtExtension;$preprocessingTime;$gatesSetup;$gatesOnline"

        # put all collected info into one row (Full)
        echo -e "$basicInfo;$loopvalues$runtimeint;$runtimeext;$maxRAMused;$jobCPU;$basicComm;$basicMes;$measurementvalues" >> "$datatableFull"

        # locate next loop file
        ((++i))
    if [ "$i" -lt 10 ]; then
    loopinfo=$(find "$resultpath" -name "*0$i.loop*" -print -quit)
    else
    loopinfo=$(find "$resultpath" -name "*$i.loop*" -print -quit)
    fi
    done
    done
    # check if there was something exported
    rowcount=$(wc -l "$datatableShort" | awk '{print $1}')
    if [ "$rowcount" -lt 2 ];then
        okfail fail "nothing to export"
        #rm "$datatableShort"
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
        [ ! -d "${EXPORTPATH}" ] && mkdir results/"${EXPORTPATH}"
        cp -r ../"$EXPORTPATH" "${EXPORTPATH}"
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
