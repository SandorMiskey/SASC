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

if [[ ${SC_PATH_BASE:-"unset"} == "unset" ]]; then
	TExVerify 1 "SC_PATH_BASE is unset"
fi
cd $SC_PATH_SCRIPTS

# endregion: load common.sh
# region: check for dependencies and versions

_FabricVersions() {
	local required_version=$SC_VERSION_FABRIC
	local cryptogen_version=$( cryptogen version | grep Version: | sed 's/.*Version: //' )
	local configtxgen_version=$( configtxgen -version | grep Version: | sed 's/.*Version: //' )

	TExPrintf "required fabric binary version: $required_version"
	TExPrintf "installed cryptogen version: $cryptogen_version"
	TExPrintf "installed configtxgen version: $configtxgen_version"

	if [ "$cryptogen_version" != "$required_version" ] || [ "$configtxgen_version" != "$required_version" ]; then
		TExVerify 1  "versions do not match required"
	fi 
}
_CAVersions() {
	local required_version=$SC_VERSION_CA
	local actual_version=$( fabric-ca-client version | grep Version: | sed 's/.*Version: //' )

	TExPrintf "required ca version: $required_version"
	TExPrintf "installed fabric-ca-client version: $actual_version"

	if [ "$actual_version" != "$required_version" ]; then
		TExVerify 1  "versions do not match required"
	fi 
}

TExYN "search for dependencies?" TExDeps
TExYN "validate fabric binary versions?" _FabricVersions
TExYN "validate ca binary versions?" _CAVersions

# endregion: dependencies and versions
# region: remove config and persistent data

_WipePersistent() {
	TExPrintf "removing $SC_PATH_DATA"
	err=$( sudo rm -Rf "$SC_PATH_DATA" )
	TExVerify $? $err
	err=$( mkdir "$SC_PATH_DATA" )
	TExVerify $? $err
}

TExYN "wipe persistent data?" _WipePersistent

# endregion: remove config and persistent data
# region: process config templates


_Config() {
	export DOCKER_NS='$(DOCKER_NS)'
	export TWO_DIGIT_VERSION='$(TWO_DIGIT_VERSION)'
	TExPrintf "processing templates:"
	for template in $( find $SC_PATH_TEMPLATES/* ! -name '.*' -print ); do
		target=$( TExSetvar $template )
		target=$( echo $target | sed s+$SC_PATH_TEMPLATES+$SC_PATH_DATA+ )
		TExPrintf "$template -> $target"
		if [[ -d $template ]]; then
			err=$( mkdir -p "$target" )
			TExVerify $? $err
		elif [[ -f $template ]]; then
			( echo "cat <<EOF" ; cat $template ; echo EOF ) | sh > $target
			TExVerify $? "unable to process $template"
		else
			TExVerify 1 "$template is not valid"
		fi
	done
}

TExYN "process templates?" _Config

# endregion: process config templates
# region: org certs w/ cryptogen tool

_one_line_pem() {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

_Crypto() {
	if [[ "$(declare -p SC_CRYPTO_CONFIG)" =~ "declare -a" ]]; then
		TExPrintf "SC_CRYPTO_CONFIG is array"
		for cconf in "${SC_CRYPTO_CONFIG[@]}"
		do
			TExPrintf "processing $cconf"
			err=$( cryptogen generate --config $cconf --output="$SC_PATH_ORGS" )
			TExVerify $? $err
		done
	else
		TExPrintf "SC_CRYPTO_CONFIG is not array, processing $SC_CRYPTO_CONFIG"
		err=$( cryptogen generate --config $SC_CRYPTO_CONFIG --output="$SC_PATH_ORGS" )
		TExVerify $? $err
	fi

	SC_ORG1_PEER_PEM=$( _one_line_pem $SC_ORG1_PEER_PEM )
	SC_ORG2_PEER_PEM=$( _one_line_pem $SC_ORG2_PEER_PEM )
	SC_ORG1_CA_PEM=$( _one_line_pem $SC_ORG1_CA_PEM )
	SC_ORG2_CA_PEM=$( _one_line_pem $SC_ORG2_CA_PEM )
	_Config
}

TExYN "regenerate certificates and reprocess config files?" _Crypto

# endregion: org certs
# region: genesis block

_GenesisBlock() {
	configtxgen -profile $SC_CHANNEL_PROFILE -outputBlock "${SC_PATH_ARTIFACTS}/${SC_CHANNEL_NAME}-genesis.block" -configPath "$SC_PATH_CONF" -channelID $SC_CHANNEL_NAME
	TExVerify $? "failed to generate orderer genesis block..."

}

TExYN "create genesis block?" _GenesisBlock

# endregion: genesis block
# region: swarm init

_SwarmLeave() {
	_leave() {
		local status
		status=$( docker swarm leave --force 2>&1 )
		TExVerify $? "$status" "swarm status: $status"
	}

	local force=$TExFORCE
	TExFORCE=false
	TExYN "Removing the last manager erases all current state of the swarm. Are you sure?" _leave
	TExFORCE=$force

	unset status
	unset force
}

_SwarmInit() {
	local token
	local status
	token=$( docker swarm init ${SC_SWARM_INIT} 2>&1 )
	status=$?
	TExVerify $status "$token"
	if [ $status -eq 0 ]; then
		local token=$( printf "$token" | tr -d '\n' | sed "s/.*--token //" | sed "s/ .*$//" )
		local file=${SC_PATH_SWARM}/swarm-worker-token
		TExPrintf "swarm worker token is $token"
		echo $token > $file
		TExVerify $? "unable to write worker token to $file" "worken token is writen to $file"
	fi
	unset token
	unset status
	unset file
}

TExYN "leave docker swarm?" _SwarmLeave
TExYN "init docker swarm?" _SwarmInit

# endregion: swarm init
# region: bootstrap stacks

_SwarmBootstrap() {
	# network
	local out
	out=$( docker network create $SC_NETWORK_INIT 2>&1 )
	TExVerify $? "failed to create network: `echo $out`" "network $SC_NETWORK_NAME is up"

	# config files
	local cfg
	cfg=$( find $SC_PATH_SWARM/*yaml ! -name '.*' -print 2>&1 )
	TExVerify $? "$cfg"

	# deploy
	for cfg in $cfg; do
		local stack
		local out
		stack=$( printf $cfg | sed "s/.*_//" | sed "s/.yaml//" | sed "s/^/${SC_NETWORK_NAME}_/" )
		TExPrintf "deploying $cfg as ${stack}"
		out=$( docker stack deploy -c $cfg $stack 2>&1 )
		TExVerify $? "failed to deploy $stack: `echo $out`" "stack deploy msg: `echo $out`"
		TExSleep $SC_SWARM_DELAY
	done
	unset out
	unset cfg
}

TExYN "bootstrap stacks?" _SwarmBootstrap

# endregion: bootstrap stacks

# TODO: peer connection to couchdb?, ports?, 
