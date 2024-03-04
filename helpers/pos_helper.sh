#!/bin/bash

# This script orchestrates the execution of the different scripts and benchmarking steps
# Additionally, it provides logging functionality with different progress messages as well as a progress bar for the execution of the experiments
# It is framework independent and does generally not need to be adjusted, except is special parameters are required
# for experiment execution or framework installation

initializePOS() {

echo "  freeing host(s) ${NODES[*]}"
for node in "${NODES[@]}"; do
	# -k: keep calender entry
	{ "$POS" allocations free -k "$node"; } ||
		error ${LINENO} "${FUNCNAME[0]} allocations free failed for $node"
done

# allocate all NODES at once and store alloc id
# sed shifts output lines by four blanks for pretty formating
echo "  allocating host(s) ${NODES[*]}"
echo $NODES
{ ALLOC_ID=$("$POS" allocations allocate "${NODES[@]}" | sed 's/^/    /'); } ||
	error ${LINENO} "${FUNCNAME[0]} allocations allocate failed"
echo "$ALLOC_ID"
RPATH=$(echo "$ALLOC_ID" | grep Results | awk '{print $3}')
ALLOC_ID=$(echo "$ALLOC_ID" | grep Alloc | awk '{print $3}')

echo "  setting image of host(s) ${NODES[*]} to $IMAGE"
for node in "${NODES[@]}"; do
	{ "$POS" nodes image "$node" "$IMAGE"; } ||
		error ${LINENO} "${FUNCNAME[0]} NODES image failed for $node"
done

echo "  loading variables files on host(s) ${NODES[*]}"

for node in "${NODES[@]}"; do
	# default variables file for all experiments
	{ "$POS" alloc set_var "$node" global-variables.yml --as-global;
	# default variables file for concrete experiment"
	# loop variables for experiment script (append random num to mitigate conflicts)
	loopvarpath="experiments/loop-variables-$NETWORK.yml"
	"$POS" alloc set_var "$node" "$loopvarpath" --as-loop;
	} || error ${LINENO} " ${FUNCNAME[0]} alloc set_var failed for $node"

done


	echo "  resetting host(s) ${NODES[*]}"
	for node in "${NODES[@]}"; do
		# run reset blocking in background and wait for processes to end before continuing
		{ { "$POS" nodes reset "$node"; } ||
			error ${LINENO} "${FUNCNAME[0]} NODES reset on $node failed"
			echo "    $node booted successfully"; } &
		PIDS+=( $! )
	done
}

setupExperiment() {

	echo "  setting up host(s) ${NODES[*]}"
	ipaddr=2
	path=/root/sevarebenchmpyc/host_scripts/
	for node in "${NODES[@]}"; do
		{ "$POS" comm laun --infile host_scripts/host_setup.sh --blocking "$node";
		echo "      $node host setup successfull";
		echo "    running experiment setup of $node";
		"$POS" comm laun --blocking "$node" -- /bin/bash "$path"experiment-setup.sh "$ipaddr" "$SWAP" "$NETWORK" "${NODES[*]}";
		echo "      $node experiment setup successfull"; 
		} &
		PIDS+=( $! )
		((++ipaddr))
	done
}

runExperiment() {
	
	echo "  running experiment on host(s) ${NODES[*]}"
	player=0
	path=/root/sevarebenchmpyc/host_scripts
	script="$path"/measurement.sh
		
	for node in "${NODES[@]}"; do
		echo "    execute experiment on host $node..."
		{ 		"$POS" comm laun --blocking --loop "$node" -- \
				/bin/bash "$script" "$EXPERIMENT" "$player" "${TTYPES[*]}" "$NETWORK" "${#NODES[*]}" "$ETYPE";
		} &
		PIDS+=( $! )
		((++player))
	done
}

