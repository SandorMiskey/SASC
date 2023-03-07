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
TEx_PP $SC_PATH_SCRIPTS

# endregion: common
# region: functions

_printHelp() {
	TEx_Printf "usage:"
	TEx_Printf "	$0 [up|down] [flags|stack]"
	TEx_Printf ""
	TEx_Printf "flags:"
	TEx_Printf "	-h - print this message "
	TEx_Printf "	-m <up|done> - start or stop stacks"
	TEx_Printf "	-s name - stack (name must be alphanumeric) to bring in the direction of -m"
	exit 1
}

_checkMode() {
	local mode=$1
	if [[ "$mode" =~ ^(up|down|dummy)$ ]]; then
		return 0
	fi
	return 1
}

_checkStack() {
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
	_printHelp
	exit 0
else
	mode=$1
	_checkMode $mode
	[[ $? -eq 0 ]] && shift
	# if [ $? -eq 0 ]; then
	# 	shift
	# fi
fi

# endregion: mode
# region: flags	

declare -a stacks=()
while [[ $# -ge 1 ]]; do
	key="$1"
	case $key in
	-h )
		_printHelp
		exit 0
		;;
	-m )
		mode=$2
		_checkMode $mode
		if [ $? -ne 0 ]; then
			_printHelp
		fi
		shift
		;;
	-s )
		stack=$2
		_checkStack $stack
		if [ $? -ne 0 ]; then
			_printHelp
		fi
		stacks+=("${SC_NETWORK_NAME}_$stack")
		unset stack
		shift
		;;
	* )
		_checkStack $key
		if [ $? -ne 0 ]; then
			_printHelp
		fi
		stacks+=("${SC_NETWORK_NAME}_$key")
		;;
	esac
	shift
	unset key
done

# endregion: glags
# region: execute

_checkMode $mode
if [ $? -ne 0 ]; then
	_printHelp
else
	verb=are
	(( ${#stacks[@]} == 1 )) && verb=is
	(( ${#stacks[@]} <  1 )) && joined="all ${SC_NETWORK_NAME} services" || printf -v joined '%s & ' "${stacks[@]}"
	! [[ $mode == dummy ]] && TEx_Printf "${joined% & } $verb going $mode"
	unset verb
	unset joined
fi

case $mode in
	"up" )
		# network
		if [ ! "$(docker network ls --format "{{.Name}}" --filter "name=${SC_NETWORK_NAME}" | grep -w ${SC_NETWORK_NAME})" ]; then
			out=$( docker network create $SC_SWARM_NETWORK 2>&1 )
			TEx_Verify $? "failed to create network: $out" "$SC_NETWORK_NAME network is up"
			unset out
		else
			TEx_Printf "${SC_NETWORK_NAME} network already exists"
		fi

		# empty list of stacks
		if (( ${#stacks[@]} <  1 )); then
			# config files
			cfg=$( find $SC_PATH_SWARM/*yaml ! -name '.*' -print 2>&1 )
			TEx_Verify $? "$cfg"
			cfg=$(echo $cfg | sort)

			# deploy
			for cfg in $cfg; do
				stack=$( printf $cfg | sed "s/.*_//" | sed "s/.yaml//" | sed "s/^/${SC_NETWORK_NAME}_/" )
				TEx_Printf "deploying $cfg as ${stack}"
				out=$( docker stack deploy -c $cfg $stack --with-registry-auth 2>&1 )
				# TEx_Verify $? "failed to deploy $stack: `echo $out`" "$stack is deployed"
				TEx_Verify $? "failed to deploy $stack: $out" "$stack is deployed: $out"
				TEx_Sleep $SC_SWARM_DELAY "waiting ${SC_SWARM_DELAY}s for the startup to finish"
				unset out
				unset stack
			done
			unset cfg
		# non-empty list of stacks
		else
			for stack in "${stacks[@]}"; do
				cfg=$( echo "${stack}" | sed "s/^${SC_NETWORK_NAME}//")
				cfg=$( find $SC_PATH_SWARM/*${cfg}.yaml ! -name '.*' -print 2>&1 )
				TEx_Verify $? "no config found for $stack $cfg"
				TEx_Printf "deploying $cfg as ${stack}"
				out=$( docker stack deploy -c $cfg $stack --with-registry-auth 2>&1 )
				TEx_Verify $? "failed to deploy $stack: $out" "$stack is deployed: $out"
				TEx_Sleep $SC_SWARM_DELAY "waiting ${SC_SWARM_DELAY}s for the startup to finish"
				unset out
				unset cfg
			done
			unset stack
		fi
		;;
	"down" )
		(( ${#stacks[@]} <  1 )) && readarray -t stacks <<<$(docker stack ls --format "{{.Name}}")
		for stack in "${stacks[@]}"; do
			[[ $stack == ${SC_NETWORK_NAME}_* ]] && TEx_Printf "$stack is being terminated" || break
			out=$( docker stack rm $stack 2>&1 )
			TEx_Verify $? "failed to remove $stack: $out" "$stack services are removed: $out"
			unset out
		done
		unset stack
		;;
	"dummy" )
		TEx_Printf "$0 is in dummy mode"
		;;
	* )
		_printHelp
		;;
esac

unset mode
unset stacks
unset _printHelp
unset _checkMode
unset _checkStacks

# endregion: execute
