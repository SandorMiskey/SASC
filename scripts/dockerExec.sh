#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

# region: load common functions

[[ ${TEx_COMMON:-"unset"} == "unset" ]] && TEx_COMMON="./common.sh"
if [ ! -f  $TEx_COMMON ]; then
	echo "=> $TEx_COMMON not found, make sure proper path is set or you execute this from the repo's 'scrips' directory!"
	exit 1
fi
source $TEx_COMMON
TEx_PP $TEx_BASE

# endregion: common
# region: flags	

_printHelp() {
	TEx_Printf "usage:"
	TEx_Printf "	$0 [cmd] [flags]"
	TEx_Printf ""
	TEx_Printf "flags:"
	TEx_Printf "	-h - print this message "
	TEx_Printf "	-n <node name> - service to execute on, can be repeated"
	TEx_Printf "	-c <command> - command to execute, can be multiple"
	TEx_Printf "	-v - sets verbose mode regardles of environment"
	TEx_Printf "	-t - unsets verbose mode"
	TEx_Printf "	-a - add all local nodes to the list of nodes, can be isssued multiple times (shortcut to -n \"\")"
	TEx_Printf "	-r - iterate first on commands, not nodes"
	TEx_Printf "	-d - dummy mode, commands will not be executed"
	TEx_Printf "	-i - interactive mode"
}

verbose=$TEx_VERBOSE
reverse=false
TEx_DOCKEREXEC_DUMMY=false
TEx_DOCKEREXEC_IACTIVE=false
declare -a nodes=()
declare -a commands=()
while [[ $# -ge 1 ]]; do
	key="$1"
	case $key in
		-h )
			_printHelp
			exit 0
			;;
		-n )
			nodes+=("$2")
			shift
			;;
		-c )
			commands+=("$2")
			shift
			;;
		-v )
			TEx_VERBOSE=true
			;;
		-t )
			TEx_VERBOSE=false
			;;
		-a )
			# for node in $( docker ps --format "{{.Names}}"); do nodes+=("$node"); done
			nodes+=("")
			unset node
			;;
		-r )
			reverse=true
			;;
		-d )
			TEx_DOCKEREXEC_DUMMY=true
			;;
		-i )
			TEx_DOCKEREXEC_IACTIVE=true
			;;
		* )
			commands+=("$key")
			;;
	esac
	shift
	unset key
done
(( ${#commands[@]} == 0 )) && commands+=("uname -a" "hostname")
# (( ${#nodes[@]} < 1 )) && TEx_Verify 1 "no actual node to execute commands on"

# endregion: flags
# region: nodes

declare -a nodesActual=()
for node in "${nodes[@]}"; do
	list=$(docker ps --format "{{.Names}}" -f "name=$node")
	[[ -z "$list" ]] && TEx_Verify 1 "cannot resolv \"$node\" as node" || TEx_Printf "\"$node\" as node name is resolved to \"$list\""
	for resolved in $list; do nodesActual+=("$resolved"); done
	unset node
	unset resolved
done
if (( ${#nodesActual[@]} < 1 )); then
	[[ "$TEx_DOCKEREXEC_DUMMY" == true ]] || TEx_Verify 1 "no actual node to execute commands on"
fi
unset nodes

# endregion: nodes
# region: execute

(( ${#commands[@]} > 1 )) && cs=s || cs="" 
(( ${#nodesActual[@]} > 1 )) && ns=s || ns="" 
TEx_Printf "command${cs} to be executed: $(TEx_JoinArray commands "\n%s" "")"
TEx_Printf "node${ns} to execute command${cs} on: $(TEx_JoinArray nodesActual "\n%s" "")"
unset cs ns

TEx_DockerExec() {
	local node="$1"
	local cmd="$2"
	local out=""
	local res=0
	[[ "$TEx_DOCKEREXEC_IACTIVE" == true ]] && local imode=" in interactive mode" || local imode=""
	[[ "$TEx_DOCKEREXEC_DUMMY" == true ]] && local dmode="NOT (because of TEx_DOCKEREXEC_DUMMY mode is set) " || local dmode=""
	TEx_Printf "\"$cmd\" will ${dmode}be executed on \"$node\"$imode"

	[[ "$TEx_DOCKEREXEC_DUMMY" == true ]] && return
	case $TEx_DOCKEREXEC_IACTIVE in
		true )
			local temp=$( mktemp "${TMPDIR:-/tmp/}$(basename "$0").XXXXXX" )
			# set -o pipefail
			docker exec -it $(docker ps -q -f name="$node" ) $cmd 2>&1 | tee $temp
			# res=$?
			res=${PIPESTATUS[0]}
			out=`cat $temp`
			rm $temp
		;;
		* )
			out=$( docker exec -it $(docker ps -q -f name="$node" ) $cmd 2>&1 )
			res=$?
		;;
	esac

	if [ "$TEx_VERBOSE" == true ]; then
		TEx_Verify $res "$out" "command output: $out"
	else
		if [[ $res -eq 0 ]]; then
			[[ "$TEx_DOCKEREXEC_IACTIVE" == true ]] || echo "$out"
		else
			[[ "$TEx_DOCKEREXEC_IACTIVE" == true ]] || TEx_Verify $res "$out"
		fi
	fi
	unset res out
}

case $reverse in
	true )
		TEx_Printf "-r has been set, so it will be iterated first on the commands, then on the nodes"
		for cmd in "${commands[@]}"; do
			for node in "${nodesActual[@]}"; do
				TEx_DockerExec "$node" "$cmd"
			done
			unset cmd
			unset node
		done
	;;
	* ) 
		for node in "${nodesActual[@]}"; do
			for cmd in "${commands[@]}"; do
				TEx_DockerExec "$node" "$cmd"
			done
			unset cmd
			unset node
		done
	;;
esac

# endregion: execute
# region: closing provisions

TEx_VERBOSE=$verbose
unset reverse
unset commands
unset nodesActual
unset verbose

# endregion: closing
