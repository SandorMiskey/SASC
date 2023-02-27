#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

# region: load common functions

[[ ${SC_PATH_COMMON:-"unset"} == "unset" ]] && SC_PATH_COMMON="./common.sh"
if [ ! -f  $SC_PATH_COMMON ]; then
	echo "=> ./common.sh not found, make sure SC_PATH_COMMON is set or you execute this from the repo's 'scrips' directory!"
	exit 1
fi
source $SC_PATH_COMMON

TExPP $SC_PATH_SCRIPTS

# endregion: common
# region: functions

printHelp() {
	TExPrintf "usage:"
	TExPrintf "	$0 [up|down] [flags|stack]"
	TExPrintf ""
	TExPrintf "flags:"
	TExPrintf "	-h - print this message "
	TExPrintf "	-m <up|done> - start or stop stacks"
	TExPrintf "	-s name - stack (name must be alphanumeric) to bring in the direction of -m"
	exit 1
}

checkMode() {
	local mode=$1
	if [[ "$mode" =~ ^(up|down|dummy)$ ]]; then
		return 0
	fi
	return 1
}

checkStack() {
	local stack=$1
	if [[ "$stack" =~ [^a-zA-Z0-9]  ]]; then
		return 1
	fi
	return 0
}

# endregion: functions
# region: mode

mode=""
if [[ $# -lt 1 ]] ; then
	printHelp
	exit 0
else
	mode=$1
	checkMode $mode
	if [ $? -eq 0 ]; then
		shift
	fi
fi

# endregion: mode
# region: flags	

declare -a stacks=()
while [[ $# -ge 1 ]]; do
	key="$1"
	case $key in
	-h )
		printHelp
		exit 0
		;;
	-m )
		mode=$2
		checkMode $mode
		if [ $? -ne 0 ]; then
			printHelp
		fi
		shift
		;;
	-s )
		stack=$2
		checkStack $stack
		if [ $? -ne 0 ]; then
			printHelp
		fi
		stacks+=("${SC_NETWORK_NAME}_$stack")
		shift
		;;
	* )
		checkStack $key
		if [ $? -ne 0 ]; then
			printHelp
		fi
		stacks+=("${SC_NETWORK_NAME}_$key")
		;;
	esac
	shift
done

# endregion: glags
# region: execute

checkMode $mode
if [ $? -ne 0 ]; then
	printHelp
else
	verb=are
	(( ${#stacks[@]} == 1 )) && verb=is
	(( ${#stacks[@]} <  1 )) && joined="all ${SC_NETWORK_NAME} services" || printf -v joined '%s & ' "${stacks[@]}"
	! [[ $mode == dummy ]] && TExPrintf "${joined% & } $verb going $mode"
fi

case $mode in
	"up" )
		# network
		if [ ! "$(docker network ls --format "{{.Name}}" --filter "name=${SC_NETWORK_NAME}" | grep -w ${SC_NETWORK_NAME})" ]; then
			out=$( docker network create $SC_SWARM_NETWORK 2>&1 )
			TExVerify $? "failed to create network: `echo $out`" "$SC_NETWORK_NAME network is up"
			unset out
		else
			TExPrintf "${SC_NETWORK_NAME} network already exists"
		fi

		# empty list of stacks
		if (( ${#stacks[@]} <  1 )); then
			# config files
			cfg=$( find $SC_PATH_SWARM/*yaml ! -name '.*' -print 2>&1 )
			TExVerify $? "$cfg"
			cfg=$(echo $cfg | sort)

			# deploy
			for cfg in $cfg; do
				stack=$( printf $cfg | sed "s/.*_//" | sed "s/.yaml//" | sed "s/^/${SC_NETWORK_NAME}_/" )
				TExPrintf "deploying $cfg as ${stack}"
				out=$( docker stack deploy -c $cfg $stack --with-registry-auth 2>&1 )
				TExVerify $? "failed to deploy $stack: `echo $out`" "$stack is deployed"
				TExSleep $SC_SWARM_DELAY
				unset out
				unset stack
			done
			unset cfg
		# non-empty list of stacks
		else
			for stack in "${stacks[@]}"; do
				cfg=$( echo "${stack}" | sed "s/^${SC_NETWORK_NAME}//")
				cfg=$( find $SC_PATH_SWARM/*${cfg}.yaml ! -name '.*' -print 2>&1 )
				TExVerify $? "no config found for $stack $cfg"
				TExPrintf "deploying $cfg as ${stack}"
				out=$( docker stack deploy -c $cfg $stack --with-registry-auth 2>&1 )
				TExVerify $? "failed to deploy $stack: `echo $out`" "$stack is deployed"
				TExSleep $SC_SWARM_DELAY
				unset out
				unset cfg
			done
			unset stack
		fi
		;;
	"down" )
		(( ${#stacks[@]} <  1 )) && readarray -t stacks <<<$(docker stack ls --format "{{.Name}}")
		for stack in "${stacks[@]}"; do
			[[ $stack == ${SC_NETWORK_NAME}_* ]] && TExPrintf "$stack is being terminated" || break
			out=$( docker stack rm $stack 2>&1 )
			TExVerify $? "failed to remove $stack: `echo $out`" "$stack services are removed"
		done
		;;
	"dummy" )
		TExPrintf "$0 is in dummy mode"
		;;
	* )
		printHelp
		;;
esac


# endregion: execute