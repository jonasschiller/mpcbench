#!/bin/bash
# shellcheck disable=2034



source ../protocols.sh
source ../helpers/testresults_helper.sh
source ../helpers/style_helper.sh

for dir in $1; do
    echo "now applying to $dir"

    EXPORTPATH="${dir::15}/${dir:16}"

    SUMMARYFILE=$(find "$dir" -name "*run-summary.dat")
    [ ! -f "$SUMMARYFILE" ] && { echo "  File not found - skipping"; continue; }

    RPATH=$(grep "POS files location" "$SUMMARYFILE" | cut -c 24-)
    [ -z "$RPATH" ] && { echo "  POS files location not found - skipping"; continue; }

    read -r -a NODES <<< "$(grep 'Nodes' "$SUMMARYFILE" | cut -c 13-)"
    [ "${#NODES[*]}" -lt 1 ] && { echo "  NODES not found - skipping"; continue; }

    resultpath="$RPATH/${NODES[0]}/"
    [ ! -d "$resultpath" ] && { echo "  Resultpath not found - different server - skipping"; continue; }

    EXPERIMENT=$(grep "Experiment = " results/2022-09-12_20-27-08/E35-run-summary.dat | cut -c 18-)
    [ -z "$EXPERIMENT" ] && { echo "  EXPERIMENT not found - skipping"; continue; }


    [ -f "$EXPORTPATH/${SUMMARYFILE:28}" ] && { echo "  Files maybe already exported - skipping"; continue; }

    echo "  exporting measurement results to $EXPORTPATH..."
    # create and push Result Plots  
    exportExperimentResults

    cp "$SUMMARYFILE" "$EXPORTPATH/"

    sleep 1s
done

