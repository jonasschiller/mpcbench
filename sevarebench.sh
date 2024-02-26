#!/bin/bash

#
# framework for running MP-SPDZ programs on TUMI8 testbed environment
# 

source helpers/style_helper.sh
source helpers/parameters.sh
source helpers/trap_helper.sh
source helpers/pos_helper.sh

#checks whether the provided number of arguments is zero and prints help message listing parameters
[ "${#@}" -eq 0 ] && usage "no parameters or config file recognized"

echo "setting experiment parameters"
#sending all parameters to the function
setParameters "$@"

echo "initializing experiment hosts..."
PIDS=()
initializePOS

sleep 2 && echo " ...waiting for initialization"
for pid in "${PIDS[@]}"; do
    wait "$pid"
done

echo "setting experiment hosts..."
PIDS=()
setupExperiment

sleep 2 && echo " ...waiting for setup"
for pid in "${PIDS[@]}"; do
    wait "$pid"
done

echo "host setup complete"

RUNSTATUS="${Orange}incomplete${Stop}"

source helpers/testresults_helper.sh


echo "running experiment on hosts..."
PIDS=()
runExperiment 

sleep 2 && echo " ...waiting for experiment"
for pid in "${PIDS[@]}"; do
    # and error on the testnodes can be caught here
    wait "$pid" || getlastoutput
done

RUNSTATUS="${Green}completed${Stop}"