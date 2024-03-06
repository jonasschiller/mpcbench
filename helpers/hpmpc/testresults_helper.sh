#!/bin/bash
# shellcheck disable=SC2154,2034

# where we find the experiment results
resultpath="$RPATH/${NODES[0]}/"

# verify testresults
verifyExperiment() {

    i=0
    failcount=0
    loopinfo=$(find "$resultpath" -name "*$i.loop*" -print -quit)
    # while we find a next loop info file do
    while [ -n "$loopinfo" ]; do

        # get pos filepath of the measurements for the current loop
        experimentresult=$(find "$resultpath" -name "terminal_output_run*$i".txt -print -quit)

        # check existance of files
        if [ ! -f "$experimentresult" ]; then
            styleOrange "  Skip $protocol - File not found error: $experimentresult"
        else
            # verify experiment result - call experiment specific verify script
            result=$(grep -c "00000001" "$experimentresult")
            if [ "$result" == 0 ]; then
                styleOrange "    Error $protocol - 00000001 not found in $experimentresult"
                ((++failcount))
            fi
        fi
        if [ "$failcount" -gt 10 ]; then
            okfail fail "  stopping verification after 10 Errors"
            return
        fi
        ((++i))
        loopinfo=$(find "$resultpath" -name "*$i.loop*" -print -quit)
    done

    # only pass if while-loop actually entered
    [ "$i" -gt 0 ] && okfail ok "  done - test finished"

}

############
# Export experiment data from the pos_upload-ed logs into two tables
############
exportExperimentResults() {

    # set up location
    datatableShort="$EXPORTPATH/data/Eslice_short_results.csv"

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
    basicInfo1="comp.time(s);comp.peakRAM(MiB);bin.filesize(MiB);"
    basicInfo2="${dyncolumns}inittime(s);preproc(s);runtime_clock(s);runtime_getTime(s);runtime_chrono(s);runtime_external(s);peakRAM(MiB);jobCPU(%)"
    echo -e "${basicInfo1}${basicInfo2}" > "$datatableShort"

    i=0
    # get loopfile path for the current variables
    loopinfo=$(find "$resultpath" -name "*$i.loop*" -print -quit)
    echo "  exporting testresults"
    # while we find a next loop info file do
    while [ -n "$loopinfo" ]; do
        loopvalues=""
        # extract loop variables/switches values
        for value in $(jq -r 'values[]' "$loopinfo"); do
            loopvalues+="$value;"
        done
        
        # get pos filepath of the measurements for the current loop
        runtimeinfo=$(find "$resultpath" -name "testresults*$i" -print -quit)
        if [ ! -f "$runtimeinfo" ]; then
            styleOrange "    Skip - File not found error: testresults*$i"
            ((++i))
            loopinfo=$(find "$resultpath" -name "*$i.loop*" -print -quit)
            continue
        fi

        # extract measurement
        compiletime=$(grep "Elapsed wall clock" "$runtimeinfo" | head -n 2 | tail -n 1 | cut -d ' ' -f 1)
        compilemaxRAMused=$(grep "Maximum resident" "$runtimeinfo" | head -n 2 | tail -n 1 | cut -d ' ' -f 1)
        binfsize=$(grep "Binary file size" "$runtimeinfo" | tail -n 1 | cut -d ' ' -f 1)
        [ -n "$compilemaxRAMused" ] && compilemaxRAMused="$((compilemaxRAMused/1024))"
        inittime=$(grep "measured to initialize program" "$runtimeinfo" | tail -n 1 | awk '{print $6}')
        inittime=${inittime:-NAs}
        preproctime=$(grep "preprocessing chrono" "$runtimeinfo" | tail -n 1 | awk '{print $7}')
        preproctime=${preproctime:-NAs}
        runtimeclock=$(grep "computation clock" "$runtimeinfo" | tail -n 1 | awk '{print $7}')
        runtimegetTime=$(grep "computation getTime" "$runtimeinfo" | tail -n 1 | awk '{print $7}')
        runtimechrono=$(grep "computation chrono" "$runtimeinfo" | tail -n 1 | awk '{print $7}')
        runtimeext=$(grep "Elapsed wall clock" "$runtimeinfo" | tail -n 1 | cut -d ' ' -f 1)
        maxRAMused=$(grep "Maximum resident" "$runtimeinfo" | tail -n 1 | cut -d ' ' -f 1)
        [ -n "$maxRAMused" ] && maxRAMused="$((maxRAMused/1024))"
        jobCPU=$(grep "CPU this job" "$runtimeinfo" | tail -n 1 | cut -d '%' -f 1)
        maxRAMused=${maxRAMused:-NA}
        compilemaxRAMused=${compilemaxRAMused:-NA}

        commRounds=$(grep "Data sent =" "$runtimeinfo" | awk '{print $7}')
        dataSent=$(grep "Data sent =" "$runtimeinfo" | awk '{print $4}')
        globaldataSent=$(grep "Global data sent =" "$runtimeinfo" | awk '{print $5}')
        basicComm="${commRounds:-NA};${dataSent:-NA};${globaldataSent:-NA}"

        # put all collected info into one row (Short)
        basicInfo="${compiletime:-NA};$compilemaxRAMused;${binfsize:-NA}"
        echo -e "$basicInfo;$loopvalues${inittime::-1};${preproctime::-1};${runtimeclock::-1};${runtimegetTime::-1};${runtimechrono::-1};${runtimeext:-NA};$maxRAMused;$jobCPU" >> "$datatableShort"

        # locate next loop file
        ((++i))
        loopinfo=$(find "$resultpath" -name "*$i.loop*" -print -quit)
    done

    # check if there was something exported
    rowcount=$(wc -l "$datatableShort" | awk '{print $1}')
    if [ "$rowcount" -lt 2 ];then
        okfail fail "nothing to export"
        rm "$datatableShort"
        return
    fi

    # create a tab separated table for pretty formatting
    # convert .csv -> .tsv
    column -s ';' -t "$datatableShort" > "${datatableShort::-3}"tsv
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

    echo "  pushing experiment measurement data to git repo$repourl"
    cd git-upload || error ${LINENO} "${FUNCNAME[0]} cd into gitrepo failed"
    {
        # a pull is not really required, but for small sizes it doesn't hurt
        git pull
        # copy from local folder to git repo folder
        [ ! -d "$EXPORTPATH" ] && mkdir -p "$EXPORTPATH"
        cp -r ../"$EXPORTPATH" "${EXPORTPATH::-11}"
        git add . 
        git commit -a -m "script upload"
        git push 
    } &> /dev/null || error ${LINENO} "${FUNCNAME[0]} git upload failed"
        okfail ok " upload success" 
}
