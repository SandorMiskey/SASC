#!/bin/sh

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

# region: load common functions

[[ ${SCxCommon:-"unset"} == "unset" ]] && SCxCommon="./common.sh"
if [ ! -f  $SCxCommon ]; then
	echo "=> ./common.sh not found, make sure SCxCommon is set or you execute this from the repo's 'scrips' directory!"
	exit 1
fi
source $SCxCommon

# endregion: load common.sh
# region: check for dependencies and versions

_FabricVersions() {
	local required_version=$SCxFabricV
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
	local required_version=$SCxCAV
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
	TExPrintf "removing $SCxData"
	err=$( rm -Rf "$SCxData" )
	TExVerify $? $err
	err=$( mkdir "$SCxData" )
	TExVerify $? $err
	# err=$( mkdir "$SCxConf" )
	# TExVerify $? $err
	# err=$( mkdir "$SCxCrypto" )
	# TExVerify $? $err
}

TExYN "wipe persistent data?" _WipePersistent

# endregion: remove config and persistent data
# region: process config templates


_Config() {
	TExPrintf "processing templates:"
	for template in $( find $SCxTemps/* ! -name '.*' -print ); do
		target=$( TExSetvar $template )
		target=$( echo $target | sed s+$SCxTemps+$SCxData+ )
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
	if [[ "$(declare -p SCxCryptoConfig)" =~ "declare -a" ]]; then
		TExPrintf "SCxCryptoConfig is array"
		for cconf in "${SCxCryptoConfig[@]}"
		do
			TExPrintf "processing $cconf"
			err=$( cryptogen generate --config $cconf --output="$SCxCrypto" )
			TExVerify $? $err
		done
	else
		TExPrintf "SCxCryptoConfig is not array, processing $SCxCryptoConfig"
		err=$( cryptogen generate --config $SCxCryptoConfig --output="$SCxCrypto" )
		TExVerify $? $err
	fi

	SCxOrg1PeerPEM=$( _one_line_pem $SCxOrg1PeerPEM )
	SCxOrg2PeerPEM=$( _one_line_pem $SCxOrg2PeerPEM )
	SCxOrg1CAPEM=$( _one_line_pem $SCxOrg1CAPEM )
	SCxOrg2CAPEM=$( _one_line_pem $SCxOrg2CAPEM )
	_Config
}

TExYN "regenerate certificates and reprocess config files?" _Crypto

# endregion: org certs
# region:

_GenesisBlock() {
	configtxgen -profile $SCxGenesisProfile -outputBlock "${SCxArtifacts}/${SCxChannel}-genesis.block" -configPath "$SCxConf" -channelID $SCxChannel
	TExVerify $? "failed to generate orderer genesis block..."

}

TExYN "create genesis block?" _GenesisBlock

# endregion:
