#!/bin/sh

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

# region: variables

# region: paths

# SCxBase=/Users/SMiskey/Desktop/SASC
export SCxBin=${SCxBase}/bin
export SCxCommon=${SCxBase}/scripts/common.sh
export SCxTemps=${SCxBase}/templates
export SCxData=${SCxBase}/data
export SCxArtifacts=${SCxData}/artifacts
export SCxChains=${SCxData}/chains
export SCxConf=${SCxData}/conf
export SCxCrypto=${SCxData}/orgs

export PATH=${SCxBin}:${SCxBase}/scripts:$PATH

# endregion: paths
# region: fabric and co

SCxCAV=1.5.5
SCxFabricV=2.4.7
SCxFabricLoggingSpec=DEBUG	# FATAL | PANIC | ERROR | WARNING | INFO | DEBUG

# endregion: fabric
# region: orgs and channels

export SCxNetwork=sasc
export SCxDomain=${SCxNetwork}.te-food.com
export SCxGenesisProfile=TwoOrgsApplicationGenesis
export SCxChannel=${SCxNetwork}-default

export SCxOrderer1Name=Orderer
export SCxOrderer1P0Port=7050		# 7050
export SCxOrderer1P0AdminPort=7051	# 7053
export SCxOrderer1P0OpPort=7052		# 9443

export SCxOrg1Name=Org1
export SCxOrg1CAPort=8050
export SCxOrg1P0Port=8051
export SCxOrg1PeerPEM=${SCxCrypto}/peerOrganizations/${SCxOrg1Name}.${SCxDomain}/tlsca/tlsca.${SCxOrg1Name}.${SCxDomain}-cert.pem
export SCxOrg1CAPEM=${SCxCrypto}/peerOrganizations/${SCxOrg1Name}.${SCxDomain}/ca/ca.${SCxOrg1Name}.${SCxDomain}-cert.pem

export SCxOrg2Name=Org2
export SCxOrg2CAPort=9050
export SCxOrg2P0Port=9051
export SCxOrg2PeerPEM=${SCxCrypto}/peerOrganizations/${SCxOrg2Name}.${SCxDomain}/tlsca/tlsca.${SCxOrg2Name}.${SCxDomain}-cert.pem
export SCxOrg2CAPEM=${SCxCrypto}/peerOrganizations/${SCxOrg2Name}.${SCxDomain}/ca/ca.${SCxOrg2Name}.${SCxDomain}-cert.pem

# SCxCryptoConfig=${SCxConf}/crypto-config.yaml
declare -a SCxCryptoConfig=("${SCxConf}/crypto-config-${SCxOrderer1Name}.yaml" "${SCxConf}/crypto-config-${SCxOrg1Name}.yaml" "${SCxConf}/crypto-config-${SCxOrg2Name}.yaml")

# endregion: orgs
# region: funcs' params

TExFORCE=true
TExPANIC=true
TExPREREQS=('awk' 'bash' 'curl' 'git' 'go' 'jq' 'cryptogen' 'configtxgen')
TExSILENT=false

# endregion: funcs

# endregion: variables
# region: functions

TExDefaults() {
	#
	# sets default values where applicable
	#

	[[ ${TExBLUE:-"unset"} == "unset" ]] && TExBLUE='\033[0;34m'
	[[ ${TExBOLD:-"unset"} == "unset" ]] && TExBOLD=$(tput bold)
	[[ ${TExGREEN:-"unset"} == "unset" ]] && TExGREEN='\033[0;32m'
	[[ ${TExNORM:-"unset"} == "unset" ]] && TExNORM=$(tput sgr0)
	# [[ ${TExNORM:-"unset"} == "unset" ]] && TExNORM='\033[0m'
	[[ ${TExRED:-"unset"} == "unset" ]] && TExRED='\033[0;31m'
	[[ ${TExYELLOW:-"unset"} == "unset" ]] && TExYELLOW='\033[1;33m'

	[[ ${TExPREFIX:-"unset"} == "unset" ]] && TExPREFIX="==> "

	[[ ${TExFORCE:-"unset"} == "unset" ]] && TExFORCE=false
	[[ ${TExPANIC:-"unset"} == "unset" ]] && TExPANIC=false
	[[ ${TExSILENT:-"unset"} == "unset" ]] && TExSILENT=false	

	[[ ${TExPREREQS:-"unset"} == "unset" ]] && TExPREREQS=('sh')
}
TExDefaults

TExPrintf() {
	#
	# fancy echo
	#
	# usage:
	# -> cPrint "stuff to echo" <printf format string>
	#
	# possible conf variables:
	# -> TExSILENT=false
	# -> TExPREFIX="===> "
	# -> TExBOLD=$(tput bold)
	# -> TExNORM=$(tput sgr0)

	TExDefaults
	[[ "$TExSILENT" == true ]] && return
	[[ ${2:-"unset"} == "unset" ]] && format="%s\n" || format=$2

	printf $format "${TExPREFIX}$1" 
}

TExPrintfBold() {
	TExPrintf "$1" "\b${TExBOLD}%s${TExNORM}\n"
}

TExSetvar() {
	target=$1
	while [[ $target =~ ^(.*)(\{[a-zA-Z0-9_]+\})(.*)$ ]] ; do
		varname=${BASH_REMATCH[2]}
		varname=${varname#"{"}
		varname=${varname%\}}
		printf -v target "%s%s%s" "${BASH_REMATCH[1]}" "${!varname}" "${BASH_REMATCH[3]}"
	done
	printf "%s" $target
}

TExSleep() {
	#
	# sleep w/ ticker
	#
	# usage:
	# -> setSleep <secs to sleep>

	TExPrintf "sleeping for $1" "%s"
	for cnt in `seq 1 $1`; do
		printf '%s' "."
		sleep 1
	done
	echo
}

TExVerify() {
	#
	# dumps $2 if $1 -ne 0, exits if necessary
	#
	# typical usage:
	# -> TExVerify $? "error message"
	#
	# possible conf variables:
	# -> TE_PANIC=false

	TExDefaults
	if [ $1 -ne 0 ]; then
		# >&2 TExPrintf "$2" "\b${TExBOLD}%s${TExNORM}\n"
		>&2 TExPrintfBold "$2"
		if [[ "$TExPANIC" == true ]]; then
			TExPrintf "TExVerify(): TExPANIC set to 'true', leaving..." "\b%s\n"
			exit 1
		fi
	fi
}

TExDeps() {
	#
	# check if prerequisites are available
	#
	# possible conf variables:
	# -> declare -a TExPREREQS=("curl" "git" "etc")

	prereqs=("$@")
	if [ 1 -gt ${#prereqs[@]} ]; then
		TExPrintf "TExDeps(): no \$@ passed, using defaults"
		TExDefaults
		prereqs=("${TExPREREQS[@]}")
		if [ 1 -gt ${#prereqs[@]} ]; then
			declare -a prereqs=('sh')
		fi
	fi
	TExPrintf "TExDeps(): checking for ${#prereqs[@]} dependencies"
	
	for i in "${prereqs[@]}" ; do
		TExPrintf "TExDeps(): checking for $i and got " "%s"
		out=$( which $i )
		
		if [ $? -ne 0 ]
		then
			TExPrintf nothing
			TExVerify 1 "$i is missing!"
		else
			TExPrintf $out
		fi
	done

}

TExYN() {
	local question=$1
	shift

	if [ "$TExFORCE" == "true" ]; then
		# TExPrintf "forced Y for '$question'" "${TExBOLD}${TExPREFIX}%s${TExNORM} \n"
		# TExPrintf "TExYN(): forced Y for '$question'" "${TExBOLD}%s${TExNORM}\n"
		TExPrintfBold "TExYN(): forced Y for '$question'" 
		ans="Y"
	else
		read -p "${TExBOLD}${TExPREFIX}$question [Y/n]${TExNORM} " ans
	fi
	case "$ans" in
		y | Y | "")
			"$@"
			;;
		n | N)
			TExPrintf "skipping"
			;;
		*)
			TExPrintf "'y' or 'n'"
			TExYN "$question" "$@"
			;;
	esac
}

# endregion: functions
