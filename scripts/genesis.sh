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
	err=$( rm -Rf "$SC_PATH_DATA" )
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
	SCxOrg2PeerPEM=$( _one_line_pem $SCxOrg2PeerPEM )
	SC_ORG1_CA_PEM=$( _one_line_pem $SC_ORG1_CA_PEM )
	SCxOrg2CAPEM=$( _one_line_pem $SCxOrg2CAPEM )
	_Config
}

TExYN "regenerate certificates and reprocess config files?" _Crypto

# endregion: org certs
# region:

_GenesisBlock() {
	configtxgen -profile $SC_CHANNEL_PROFILE -outputBlock "${SC_PATH_ARTIFACTS}/${SC_CHANNEL_NAME}-genesis.block" -configPath "$SC_PATH_CONF" -channelID $SC_CHANNEL_NAME
	TExVerify $? "failed to generate orderer genesis block..."

}

TExYN "create genesis block?" _GenesisBlock

# endregion:
