#!/bin/sh

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

# region: variables

# region: paths

export SC_PATH_BASE=$SC_PATH_BASE
export SC_PATH_TEMPLATES=${SC_PATH_BASE}/templates
export SC_PATH_SCRIPTS=${SC_PATH_BASE}/scripts
export SC_PATH_COMMON=${SC_PATH_SCRIPTS}/common.sh
export SC_PATH_DATA=${SC_PATH_BASE}/data
export SC_PATH_ARTIFACTS=${SC_PATH_DATA}/artifacts
export SC_PATH_CHAINS=${SC_PATH_DATA}/chains
export SC_PATH_CONF=${SC_PATH_DATA}/conf
export SC_PATH_ORGS=${SC_PATH_DATA}/orgs

export PATH=${SC_PATH_BASE}/bin:${SC_PATH_SCRIPTS}:$PATH

# endregion: paths
# region: fabric and co

export SC_VERSION_CA=1.5.5
export SC_VERSION_FABRIC=2.4.7
export SC_VERSION_COUCHDB=3.1.1

export SC_COUCHDB_USER=admin
export SC_COUCHDB_PASSWORD=$SC_COUCHDB_PASSWORD

export SC_FABRIC_LOGLEVEL=DEBUG		# FATAL | PANIC | ERROR | WARNING | INFO | DEBUG

# endregion: fabric
# region: orgs and channels

export SC_NETWORK_NAME=sasc
export SC_NETWORK_DOMAIN=${SC_NETWORK_NAME}.te-food.com
export SC_CHANNEL_PROFILE=TwoOrgsApplicationGenesis
export SC_CHANNEL_NAME=${SC_NETWORK_NAME}-default
export SC_SWARM_MANAGER=ip-10-97-85-63
export SC_SWARM_INIT="--advertise-addr 35.158.186.93:2377 --listen-addr 0.0.0.0:2377 --cert-expiry 1000000h0m0s"
export SC_SWARM_VPORT=5001

export SC_ORDERER1_NAME=Orderer
export SC_ORDERER1_DOMAIN=${SC_ORDERER1_NAME}.${SC_NETWORK_DOMAIN}
export SC_ORDERER1_O1_NAME=orderer1
export SC_ORDERER1_O1_FQDN=${SC_ORDERER1_O1_NAME}.${SC_ORDERER1_DOMAIN}
export SC_ORDERER1_O1_PORT=7050			# 7050
export SC_ORDERER1_O1_ADMINPORT=7051	# 7053
export SC_ORDERER1_O1_OPPORT=7052		# 9443
export SC_ORDERER1_O1_WORKER=$SC_SWARM_MANAGER

export SC_ORG1_NAME=Org1
export SC_ORG1_DOMAIN=${SC_ORG1_NAME}.${SC_NETWORK_DOMAIN}
export SC_ORG1_PEER_PEM=${SC_PATH_ORGS}/peerOrganizations/${SC_ORG1_DOMAIN}/tlsca/tlsca.${SC_ORG1_DOMAIN}-cert.pem
export SC_ORG1_CA_PEM=${SC_PATH_ORGS}/peerOrganizations/${SC_ORG1_DOMAIN}/ca/ca.${SC_ORG1_DOMAIN}-cert.pem
export SC_ORG1_CA_PORT=8050
export SC_ORG1_P1_NAME=peer1
export SC_ORG1_P1_FQDN=${SC_ORG1_P1_NAME}.${SC_ORG1_DOMAIN}
export SC_ORG1_P1_PORT=8051
export SC_ORG1_P1_CHAINPORT=8052
export SC_ORG1_P1_OPPORT=8053
export SC_ORG1_P1_WORKER=$SC_SWARM_MANAGER
export SC_ORG1_C1_NAME=couchdb1
export SC_ORG1_C1_FQDN=${SC_ORG1_C1_NAME}.${SC_ORG1_DOMAIN}
export SC_ORG1_C1_PORT=8054
export SC_ORG1_C1_WORKER=$SC_SWARM_MANAGER

export SC_ORG2_NAME=Org2
export SC_ORG2_DOMAIN=${SC_ORG2_NAME}.${SC_NETWORK_DOMAIN}
export SC_ORG2_PEER_PEM=${SC_PATH_ORGS}/peerOrganizations/${SC_ORG2_DOMAIN}/tlsca/tlsca.${SC_ORG2_DOMAIN}-cert.pem
export SC_ORG2_CA_PEM=${SC_PATH_ORGS}/peerOrganizations/${SC_ORG2_DOMAIN}/ca/ca.${SC_ORG2_DOMAIN}-cert.pem
export SC_ORG2_CA_PORT=9050
export SC_ORG2_P1_NAME=peer1
export SC_ORG2_P1_FQDN=${SC_ORG2_P1_NAME}.${SC_ORG2_DOMAIN}
export SC_ORG2_P1_PORT=9051
export SC_ORG2_P1_CHAINPORT=9052
export SC_ORG2_P1_OPPORT=9053
export SC_ORG2_P1_WORKER=$SC_SWARM_MANAGER
export SC_ORG2_C1_NAME=couchdb1
export SC_ORG2_C1_FQDN=${SC_ORG1_C2_NAME}.${SC_ORG2_DOMAIN}
export SC_ORG2_C1_PORT=9054
export SC_ORG2_C1_WORKER=$SC_SWARM_MANAGER

# SC_CRYPTO_CONFIG=${SC_PATH_CONF}/crypto-config.yaml
declare -a SC_CRYPTO_CONFIG=("${SC_PATH_CONF}/crypto-config-${SC_ORDERER1_NAME}.yaml" "${SC_PATH_CONF}/crypto-config-${SC_ORG1_NAME}.yaml" "${SC_PATH_CONF}/crypto-config-${SC_ORG2_NAME}.yaml")

# endregion: orgs
# region: funcs' params

TExFORCE=true
TExPANIC=true
TExPREREQS=('awk' 'bash' 'curl' 'git' 'go' 'jq' 'cryptogen' 'configtxgen')
TExSILENT=false

# endregion: funcs

# endregion: variables
# region: functions

TExCheckBase() {
	if [[ ${SC_PATH_BASE:-"unset"} == "unset" ]]; then
		false
	else
		true
	fi
}

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
	if [ $1 -ne 0 ]
	then
		# >&2 TExPrintf "$2" "\b${TExBOLD}%s${TExNORM}\n"
		>&2 TExPrintfBold "$2"
		if [[ "$TExPANIC" == true ]]; then
			TExPrintf "TExVerify(): TExPANIC set to 'true', leaving..." "\b%s\n"
			exit 1
		fi
	else
		if [ -z ${3+x} ]; then echo -n ""; else TExPrintf "$3"; fi
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
