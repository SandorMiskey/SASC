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
	TEx_Verify 1 "SC_PATH_BASE is unset"
fi
TEx_PP $SC_PATH_SCRIPTS

# endregion: load common.sh
# region: check for dependencies and versions

_FabricVersions() {
	local required_version=$SC_VERSION_FABRIC
	local cryptogen_version=$( cryptogen version | grep Version: | sed 's/.*Version: //' )
	local configtxgen_version=$( configtxgen -version | grep Version: | sed 's/.*Version: //' )

	TEx_Printf "required fabric binary version: $required_version"
	TEx_Printf "installed cryptogen version: $cryptogen_version"
	TEx_Printf "installed configtxgen version: $configtxgen_version"

	if [ "$cryptogen_version" != "$required_version" ] || [ "$configtxgen_version" != "$required_version" ]; then
		TEx_Verify 1  "versions do not match required"
	fi 
}
_CAVersions() {
	local required_version=$SC_VERSION_CA
	local actual_version=$( fabric-ca-client version | grep Version: | sed 's/.*Version: //' )

	TEx_Printf "required ca version: $required_version"
	TEx_Printf "installed fabric-ca-client version: $actual_version"

	if [ "$actual_version" != "$required_version" ]; then
		TEx_Verify 1  "versions do not match required"
	fi 
}

TEx_YN "search for dependencies?" TEx_Deps
TEx_YN "validate fabric binary versions?" _FabricVersions
TEx_YN "validate ca binary versions?" _CAVersions

# endregion: dependencies and versions
# region: remove config and persistent data

_WipePersistent() {
	TEx_Printf "removing $SC_PATH_DATA"
	err=$( sudo rm -Rf "$SC_PATH_DATA" )
	TEx_Verify $? $err
	err=$( mkdir "$SC_PATH_DATA" )
	TEx_Verify $? $err
}

TEx_YN "wipe persistent data?" _WipePersistent

# endregion: remove config and persistent data
# region: process config templates


_Config() {
	export DOCKER_NS='$(DOCKER_NS)'
	export TWO_DIGIT_VERSION='$(TWO_DIGIT_VERSION)'
	TEx_Printf "processing templates:"
	for template in $( find $SC_PATH_TEMPLATES/* ! -name '.*' -print ); do
		target=$( TEx_Setvar $template )
		target=$( echo $target | sed s+$SC_PATH_TEMPLATES+$SC_PATH_DATA+ )
		TEx_Printf "$template -> $target"
		if [[ -d $template ]]; then
			err=$( mkdir -p "$target" )
			TEx_Verify $? $err
		elif [[ -f $template ]]; then
			( echo "cat <<EOF" ; cat $template ; echo EOF ) | sh > $target
			TEx_Verify $? "unable to process $template"
		else
			TEx_Verify 1 "$template is not valid"
		fi
	done
}

TEx_YN "process templates?" _Config

# endregion: process config templates
# region: org certs w/ cryptogen tool

_one_line_pem() {
    echo "`awk 'NF {sub(/\\n/, ""); printf "%s\\\\\\\n",$0;}' $1`"
}

_Crypto() {
	if [[ "$(declare -p SC_CRYPTO_CONFIG)" =~ "declare -a" ]]; then
		TEx_Printf "SC_CRYPTO_CONFIG is array"
		for cconf in "${SC_CRYPTO_CONFIG[@]}"
		do
			TEx_Printf "processing $cconf"
			err=$( cryptogen generate --config $cconf --output="$SC_PATH_ORGS" )
			TEx_Verify $? $err
		done
	else
		TEx_Printf "SC_CRYPTO_CONFIG is not array, processing $SC_CRYPTO_CONFIG"
		err=$( cryptogen generate --config $SC_CRYPTO_CONFIG --output="$SC_PATH_ORGS" )
		TEx_Verify $? $err
	fi

	SC_ORG1_PEER_PEM=$( _one_line_pem $SC_ORG1_PEER_PEM )
	SC_ORG2_PEER_PEM=$( _one_line_pem $SC_ORG2_PEER_PEM )
	SC_ORG1_CA_PEM=$( _one_line_pem $SC_ORG1_CA_PEM )
	SC_ORG2_CA_PEM=$( _one_line_pem $SC_ORG2_CA_PEM )
	_Config
}

TEx_YN "regenerate certificates and reprocess config files?" _Crypto

# endregion: org certs
# region: swarm init and bootstrap stacks

_SwarmLeave() {
	_leave() {
		local status
		status=$( docker swarm leave --force 2>&1 )
		TEx_Verify $? "$status" "swarm status: $status"
	}

	local force=$TEx_FORCE
	TEx_FORCE=$SC_SURE
	TEx_YN "Removing the last manager erases all current state of the swarm. Are you sure?" _leave
	TEx_FORCE=$force

	unset status
	unset force
}

_SwarmInit() {
	local token
	local status
	token=$( docker swarm init ${SC_SWARM_INIT} 2>&1 )
	status=$?
	TEx_Verify $status "$token"
	if [ $status -eq 0 ]; then
		local token=$( printf "$token" | tr -d '\n' | sed "s/.*--token //" | sed "s/ .*$//" )
		local file=${SC_PATH_SWARM}/swarm-worker-token
		TEx_Printf "swarm worker token is $token"
		echo $token > $file
		TEx_Verify $? "unable to write worker token to $file" "worken token is writen to $file"
	fi
	unset token
	unset status
	unset file
}

_SwarmPrune() {
	_prune() {
		local status
		status=$( docker network prune -f 2>&1 )
		TEx_Verify $? "$status" "network prune: `echo $status`"
		status=$( docker volume prune -f 2>&1 )
		TEx_Verify $? "$status" "volume prune: `echo $status`"
		status=$( docker container prune -f 2>&1 )
		TEx_Verify $? "$status" "container prune: `echo $status`"
		status=$( docker image prune -f 2>&1 )
		TEx_Verify $? "$status" "image prune: `echo $status`"
	}

	local force=$TEx_FORCE
	TEx_FORCE=$SC_SURE
	TEx_YN "This will remove all local stuff not used by at least one container. Are you sure?" _prune
	TEx_FORCE=$force

	unset status
	unset force
}

TEx_YN "leave docker swarm?" _SwarmLeave
TEx_YN "init docker swarm?" _SwarmInit
TEx_YN "bootstrap stacks?" ${SC_PATH_SCRIPTS}/bootstrap.sh -m up
TEx_YN "prune networks/volumes/containers/images?" _SwarmPrune

# endregion: swarm init and bootstrap stacks
# region: create channel and join peers

_GenesisBlock() {
	# set -x
	configtxgen -profile $SC_CHANNEL_PROFILE -outputBlock "${SC_PATH_ARTIFACTS}/${SC_CHANNEL_NAME}-genesis.block" -configPath "$SC_PATH_CONF" -channelID $SC_CHANNEL_NAME
	TEx_Verify $? "failed to generate orderer genesis block..."

}

_CreateChannel() {
	local rc=1
	local cnt=1
	local out=""
	SC_SetGlobals org1

	while [ $rc -ne 0 -a $cnt -le $SC_CHANNEL_RETRY ] ; do
		TEx_Sleep $SC_CHANNEL_DELAY "${SC_CHANNEL_DELAY}s safety delay"
		out=$( osnadmin channel join --channelID ${SC_CHANNEL_NAME} --config-block "${SC_PATH_ARTIFACTS}/${SC_CHANNEL_NAME}-genesis.block" -o localhost:${SC_ORDERER1_O1_ADMINPORT} --ca-file "$ORDERER_CA" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY" )
		res=$?
		let rc=$res
		cnt=$(expr $cnt + 1)
	done
	TEx_Printf "osnadmin output: $out"
	TEx_Verify $res "channel creation failed"
}

TEx_YN "create genesis block for $SC_CHANNEL_NAME?" _GenesisBlock
TEx_YN "create channel $SC_CHANNEL_NAME?" _CreateChannel

# endregion: create channel
