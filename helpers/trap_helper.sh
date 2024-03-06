#!/bin/bash

## from https://stackoverflow.com/a/185900

# this function is called upon any exit in any event
# with the help of a trap. It shall restore the state
# of the system from before the framework was started.
# It also verifies and exports measurement results

cleanup() {

	echo running cleanup tasks
	# discard temporary files
	rm -f "${TEMPFILES[@]}"
  
  # free all NODES at once by using alloc id
  [ -z "$ALLOC_ID" ] || {
    echo "  freeing node(s) ${NODES[*]} from allocation $ALLOC_ID";
    "$POS" allocations free -k "$ALLOC_ID"; }

  # collecting results, whatever was generated, if started (incomplete) or completed
  if [[ "$RUNSTATUS" =~ complet ]]; then

    # measure total experiment runtime
    rt=$SECONDS
    {
      echo "  POS files location = $RPATH"
      echo "  Total Experiment runtime = $((rt / 3600))h$(((rt / 60) % 60))min$((rt % 60))sec"
      echo -e "  Experiment run status: $RUNSTATUS" 
    } | tee -a "$SUMMARYFILE"

    echo "verifying experiment results..."

    verifyExperiment | tee -a "$SUMMARYFILE"

    echo "exporting measurement results..."
    # create and push Result Plots  
    exportExperimentResults
  else
    rm -rf "$EXPORTPATH" &> /dev/null
  fi

  # only close if not in configrun mode
  if ! "$CONFIGRUN"; then
    # this looks up the process group of this script and
    # gracefully closes them. Otherwise running this script
    # can leave zombie processes   
    pgid=$(ps -o pgid= $$)
    echo "  closing all childs of process group ${pgid// /}"
    kill -15 -"${pgid// /}"
  fi
}

trap cleanup 0

configruntrap() {
  echo "done with config file run"
  # this looks up the process group of this script and
  # gracefully closes them. Otherwise running this script
  # can leave zombie processes   
  pgid=$(ps -o pgid= $$)
  echo "  close all childs of process group ${pgid// /}"
  kill -15 -"${pgid// /}"
}

# this function shall assist the user of the framework in
# identifying the cause of a potential problem. It can be 
# called at any point of the framework to inform on errors
# Example: error $LINENO "${FUNCNAME[0]} errormessage";
error() {
  local parent_lineno="$1"
  local message="$2"
  local code="${3:-1}"
  if [[ -n "$message" ]] ; then
    okfail 0 "Error on or near line ${parent_lineno}: ${message}; exiting with status ${code}"
  else
    okfail 0 "Error on or near line ${parent_lineno}; exiting with status ${code}"
  fi
  exit "${code}"
}

getlastoutput() {
  # this can help identifying the problem on the host by printing the last output
  filename=$(find "$RPATH/${NODES[0]}/" -name "*testresults*" -print | tail -n 1)

  if [ ! -f "$filename" ]; then
    echo "  no protocol run detected"
    error ${LINENO} "an error occured on one of the nodes"
  fi

  echo "  filename: $filename"
  echo -e "\n  Last protocol run printed:\n"
  cat "$filename"
  echo
  # get last three loop variables constellations
  echo -e "  Last three loop variables constellations:\n"
  for file in $(find "$RPATH/${NODES[0]}/" -name "*loop*" -print | tail -n 3); do 
    cat "$file"
    echo 
  done
  echo

  errorcode="${1:-1}"
  # Should the run be repeated, hand over a retry error code
  timeout="$(grep -c "exited with non-zero status 124" "$filename")"
  # timeout and more then 9 loop iterations
  [ "$timeout" -eq 1 ] && [ "${filename: -2}" -gt 9 ] && errorcode=4
  error ${LINENO} "an error occured on one of the nodes" "$errorcode"
}

trap 'error ${LINENO}' ERR