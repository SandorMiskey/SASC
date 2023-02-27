#!/bin/sh

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

# region: framework params

TEx_FORCE=true
TEx_PANIC=true
TEx_PREREQS=('awk' 'bash' 'curl' 'git' 'go' 'jq' 'cryptogen' 'configtxgen')
TEx_SILENT=false

# endregion: framework params
# region: framework functions

function TEx_CheckBase() {
	if [[ ${SC_PATH_BASE:-"unset"} == "unset" ]]; then
		false
	else
		true
	fi
}

function TEx_Defaults() {
	#
	# sets default values where applicable
	#

	[[ ${TEx_BLUE:-"unset"} == "unset" ]] && TEx_BLUE='\033[0;34m'
	[[ ${TEx_BOLD:-"unset"} == "unset" ]] && TEx_BOLD=$(tput bold)
	[[ ${TEx_GREEN:-"unset"} == "unset" ]] && TEx_GREEN='\033[0;32m'
	[[ ${TEx_NORM:-"unset"} == "unset" ]] && TEx_NORM=$(tput sgr0)
	# [[ ${TEx_NORM:-"unset"} == "unset" ]] && TEx_NORM='\033[0m'
	[[ ${TEx_RED:-"unset"} == "unset" ]] && TEx_RED='\033[0;31m'
	[[ ${TEx_YELLOW:-"unset"} == "unset" ]] && TEx_YELLOW='\033[1;33m'

	[[ ${TEx_PREFIX:-"unset"} == "unset" ]] && TEx_PREFIX="==> "
	[[ ${TEx_SUBPREFIX:-"unset"} == "unset" ]] && TEx_SUBPREFIX="    -> "

	[[ ${TEx_FORCE:-"unset"} == "unset" ]] && TEx_FORCE=false
	[[ ${TEx_PANIC:-"unset"} == "unset" ]] && TEx_PANIC=false
	[[ ${TEx_SILENT:-"unset"} == "unset" ]] && TEx_SILENT=false	

	[[ ${TEx_PREREQS:-"unset"} == "unset" ]] && TEx_PREREQS=('sh')
}
TEx_Defaults

TEx_Printf() {
	#
	# fancy echo
	#
	# usage:
	# -> TEx_Printf "stuff to print" <printf format string>
	#
	# possible conf variables:
	# -> TEx_SILENT=false
	# -> TEx_PREFIX="===> "
	# -> TEx_BOLD=$(tput bold)
	# -> TEx_NORM=$(tput sgr0)

	TEx_Defaults
	[[ "$TEx_SILENT" == true ]] && return
	[[ ${2:-"unset"} == "unset" ]] && format="%s\n" || format=$2
	printf $format "${TEx_PREFIX}$( printf "%s\n" "$1" | head -n 1 )" 
	# printf $format "${TExPREFIX}$1"

	local lines=$( printf "%s\n" "$1" | wc -l )
	local cnt=2
	if [ $lines -gt 1 ]; then
		while [ $cnt -le $lines ] ; do
			printf $format "${TEx_SUBPREFIX}$( printf "%s\n" "$1" | tail -n +$cnt | head -n 1 )" 
			cnt=$(expr $cnt + 1)
		done
	fi
}

function TEx_PrintfBold() {
	TEx_Printf "$1" "\b${TEx_BOLD}%s${TEx_NORM}\n"
}

function TEx_Setvar() {
	target=$1
	while [[ $target =~ ^(.*)(\{[a-zA-Z0-9_]+\})(.*)$ ]] ; do
		varname=${BASH_REMATCH[2]}
		varname=${varname#"{"}
		varname=${varname%\}}
		printf -v target "%s%s%s" "${BASH_REMATCH[1]}" "${!varname}" "${BASH_REMATCH[3]}"
	done
	printf "%s" $target
}

function TEx_Sleep() {
	#
	# sleep w/ ticker
	#
	# usage:
	# -> TEx_Sleep <secs to sleep> [msg]

	local delay
	local msg
	[[ ${1:-"unset"} == "unset" ]] && delay=3 || delay=$1
	[[ ${2:-"unset"} == "unset" ]] && msg="sleeping for ${delay}s" || msg=$2

	TEx_Printf "$msg" "%s"
	local cnt
	for cnt in `seq 1 $delay`; do
		printf '%s' "."
		sleep 1
	done
	echo
}

function TEx_Verify() {
	#
	# dumps $2 if $1 -ne 0, exits if necessary
	#
	# typical usage:
	# -> TEx_Verify $? "error message"
	#
	# possible conf variables:
	# -> TE_PANIC=false

	TEx_Defaults
	if [ $1 -ne 0 ]
	then
		# >&2 TEx_Printf "$2" "\b${TEx_BOLD}%s${TEx_NORM}\n"
		>&2 TEx_PrintfBold "$2"
		if [[ "$TEx_PANIC" == true ]]; then
			TEx_Printf "TEx_Verify(): TEx_PANIC set to 'true', leaving..." "\b%s\n"
			exit 1
		fi
	else
		if [ -z ${3+x} ]; then echo -n ""; else TEx_Printf "$3"; fi
	fi
}

function TEx_Deps() {
	#
	# check if prerequisites are available
	#
	# possible conf variables:
	# -> declare -a TEx_PREREQS=("curl" "git" "etc")

	prereqs=("$@")
	if [ 1 -gt ${#prereqs[@]} ]; then
		TEx_Printf "TEx_Deps(): no \$@ passed, using defaults"
		TEx_Defaults
		prereqs=("${TEx_PREREQS[@]}")
		if [ 1 -gt ${#prereqs[@]} ]; then
			declare -a prereqs=('sh')
		fi
	fi
	TEx_Printf "TEx_Deps(): checking for ${#prereqs[@]} dependencies"
	
	for i in "${prereqs[@]}" ; do
		TEx_Printf "TEx_Deps(): checking for $i and got " "%s"
		out=$( which $i )
		
		if [ $? -ne 0 ]
		then
			TEx_Printf nothing
			TEx_Verify 1 "$i is missing!"
		else
			TEx_Printf $out
		fi
	done

}

function TEx_YN() {
	local question=$1
	shift

	if [ "$TEx_FORCE" == "true" ]; then
		# TEx_Printf "forced Y for '$question'" "${TEx_BOLD}${TEx_PREFIX}%s${TEx_NORM} \n"
		# TEx_Printf "TEx_YN(): forced Y for '$question'" "${TEx_BOLD}%s${TEx_NORM}\n"
		TEx_PrintfBold "TEx_YN(): forced Y for '$question'" 
		ans="Y"
	else
		read -p "${TEx_BOLD}${TEx_PREFIX}$question [Y/n]${TEx_NORM} " ans
	fi
	case "$ans" in
		y | Y | "")
			"$@"
			;;
		n | N)
			TEx_Printf "skipping"
			;;
		*)
			TEx_Printf "'y' or 'n'"
			TEx_YN "$question" "$@"
			;;
	esac
}

function TEx_PP() {
	pushd ${PWD} > /dev/null
	trap "popd > /dev/null" EXIT
	cd $1
}

# export -f TEx_CheckBase
# export -f TEx_Defaults
# export -f TEx_Printf
# export -f TEx_PrintfBold
# export -f TEx_Setvar
# export -f TEx_Sleep
# export -f TEx_Verify
# export -f TEx_Deps
# export -f TEx_YN
# export -f TEx_PP

# endregion: functions

# region: paths

export SC_PATH_BASE=$SC_PATH_BASE
export SC_PATH_COMMON=$SC_PATH_COMMON
export SC_PATH_TEMPLATES=${SC_PATH_BASE}/templates
export SC_PATH_SCRIPTS=${SC_PATH_BASE}/scripts
export SC_PATH_DATA=${SC_PATH_BASE}/data
export SC_PATH_ARTIFACTS=${SC_PATH_DATA}/artifacts
export SC_PATH_CHAINS=${SC_PATH_DATA}/storage
export SC_PATH_CONF=${SC_PATH_DATA}/conf
export SC_PATH_ORGS=${SC_PATH_DATA}/orgs
export SC_PATH_SWARM=${SC_PATH_DATA}/swarm

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
# region: network and channel

export SC_NETWORK_NAME=SASC
export SC_NETWORK_DOMAIN=${SC_NETWORK_NAME}.te-food.com
export SC_CHANNEL_PROFILE=TwoOrgsApplicationGenesis
export SC_CHANNEL_NAME=default
export SC_CHANNEL_DELAY=3
export SC_CHANNEL_RETRY=3

# endregion: network and channel
# region: swarm

export SC_SWARM_MANAGER=ip-10-97-85-63
export SC_SWARM_NETWORK="--attachable --driver overlay --subnet 10.96.0.0/24 $SC_NETWORK_NAME"
export SC_SWARM_INIT="--advertise-addr 35.158.186.93:2377 --listen-addr 0.0.0.0:2377 --cert-expiry 1000000h0m0s"
export SC_SWARM_DELAY=1

# endregion: swarm
# region: orgs

# region: ORG1

export SC_ORG1_NAME=Org1
export SC_ORG1_DOMAIN=${SC_ORG1_NAME}.${SC_NETWORK_DOMAIN}
export SC_ORG1_PEER_PEM=${SC_PATH_ORGS}/peerOrganizations/${SC_ORG1_DOMAIN}/tlsca/tlsca.${SC_ORG1_DOMAIN}-cert.pem
export SC_ORG1_CA_PEM=${SC_PATH_ORGS}/peerOrganizations/${SC_ORG1_DOMAIN}/ca/ca.${SC_ORG1_DOMAIN}-cert.pem
export SC_ORG1_CA_PORT=5100

export SC_ORG1_C1_NAME=couchdb1
export SC_ORG1_C1_FQDN=${SC_ORG1_C1_NAME}.${SC_ORG1_DOMAIN}
export SC_ORG1_C1_PORT=5110
export SC_ORG1_C1_WORKER=$SC_SWARM_MANAGER

export SC_ORG1_P1_NAME=peer1
export SC_ORG1_P1_FQDN=${SC_ORG1_P1_NAME}.${SC_ORG1_DOMAIN}
export SC_ORG1_P1_PORT=5111
export SC_ORG1_P1_CHAINPORT=5112
export SC_ORG1_P1_OPPORT=5113
export SC_ORG1_P1_WORKER=$SC_SWARM_MANAGER

export SC_ORG1_C2_NAME=couchdb2
export SC_ORG1_C2_FQDN=${SC_ORG1_C2_NAME}.${SC_ORG1_DOMAIN}
export SC_ORG1_C2_PORT=5120
export SC_ORG1_C2_WORKER=$SC_SWARM_MANAGER

export SC_ORG1_P2_NAME=peer2
export SC_ORG1_P2_FQDN=${SC_ORG1_P2_NAME}.${SC_ORG1_DOMAIN}
export SC_ORG1_P2_PORT=5121
export SC_ORG1_P2_CHAINPORT=5122
export SC_ORG1_P2_OPPORT=5123
export SC_ORG1_P2_WORKER=$SC_SWARM_MANAGER

# endregion: ORG1
# region: ORG2

export SC_ORG2_NAME=Org2
export SC_ORG2_DOMAIN=${SC_ORG2_NAME}.${SC_NETWORK_DOMAIN}
export SC_ORG2_PEER_PEM=${SC_PATH_ORGS}/peerOrganizations/${SC_ORG2_DOMAIN}/tlsca/tlsca.${SC_ORG2_DOMAIN}-cert.pem
export SC_ORG2_CA_PEM=${SC_PATH_ORGS}/peerOrganizations/${SC_ORG2_DOMAIN}/ca/ca.${SC_ORG2_DOMAIN}-cert.pem
export SC_ORG2_CA_PORT=5200

export SC_ORG2_C1_NAME=couchdb1
export SC_ORG2_C1_FQDN=${SC_ORG2_C1_NAME}.${SC_ORG2_DOMAIN}
export SC_ORG2_C1_PORT=5210
export SC_ORG2_C1_WORKER=$SC_SWARM_MANAGER

export SC_ORG2_P1_NAME=peer1
export SC_ORG2_P1_FQDN=${SC_ORG2_P1_NAME}.${SC_ORG2_DOMAIN}
export SC_ORG2_P1_PORT=5211
export SC_ORG2_P1_CHAINPORT=5212
export SC_ORG2_P1_OPPORT=5213
export SC_ORG2_P1_WORKER=$SC_SWARM_MANAGER

export SC_ORG2_C2_NAME=couchdb2
export SC_ORG2_C2_FQDN=${SC_ORG2_C1_NAME}.${SC_ORG2_DOMAIN}
export SC_ORG2_C2_PORT=5220
export SC_ORG2_C2_WORKER=$SC_SWARM_MANAGER

export SC_ORG2_P2_NAME=peer2
export SC_ORG2_P2_FQDN=${SC_ORG2_P2_NAME}.${SC_ORG2_DOMAIN}
export SC_ORG2_P2_PORT=5221
export SC_ORG2_P2_CHAINPORT=5222
export SC_ORG2_P2_OPPORT=5223
export SC_ORG2_P2_WORKER=$SC_SWARM_MANAGER

# endregion: ORG2
# region: OEDERER1

export SC_ORDERER1_NAME=Orderer
export SC_ORDERER1_DOMAIN=${SC_ORDERER1_NAME}.${SC_NETWORK_DOMAIN}
export SC_ORDERER1_CA_PORT=5900

export SC_ORDERER1_O1_NAME=orderer1
export SC_ORDERER1_O1_FQDN=${SC_ORDERER1_O1_NAME}.${SC_ORDERER1_DOMAIN}
export SC_ORDERER1_O1_PORT=5910
export SC_ORDERER1_O1_ADMINPORT=5911
export SC_ORDERER1_O1_OPPORT=5912
export SC_ORDERER1_O1_WORKER=$SC_SWARM_MANAGER

# endregion: OEDERER1
# region: crypto config

declare -a SC_CRYPTO_CONFIG=("${SC_PATH_CONF}/crypto-config/${SC_ORDERER1_NAME}.yaml" "${SC_PATH_CONF}/crypto-config/${SC_ORG1_NAME}.yaml" "${SC_PATH_CONF}/crypto-config/${SC_ORG2_NAME}.yaml")
# SC_CRYPTO_CONFIG=${SC_PATH_CONF}/crypto-config.yaml

# endregion: crypto config

# endregion: orgs
# region: interfaces, metrics and management

export SC_UID=$SC_UID
export SC_GID=$SC_GID

export SC_INTERFACES_CLI_HOST=$SC_SWARM_MANAGER

export SC_METRICS_HOST=$SC_SWARM_MANAGER
export SC_METRICS_VISUALIZER_PORT=5050
export SC_METRICS_PROMETHEUS_PORT=5051
export SC_METRICS_CADVISOR_PORT=5052
export SC_METRICS_NEXPORTER_PORT=5053
export SC_METRICS_GRAFANA_PORT=5054
export SC_METRICS_GRAFANA_PASSWORD=$SC_METRICS_GRAFANA_PASSWORD
export SC_METRICS_LOGSPOUT_PORT=5055

export SC_MGMT_HOST=$SC_SWARM_MANAGER
export SC_MGMT_PORTAINER_PASSWORD=$SC_MGMT_PORTAINER_PASSWORD
export SC_MGMT_PORTAINER_PORT=5070

# endregion: interfaces
# region: workflow and functions

export SC_SURE=false

SC_SetGlobals() {
	local org=""
	[[ -z "$1" ]] && org=ORG1 || org=$1
	org_name="SC_${org^^}_NAME"
	org_domain="SC_${org^^}_DOMAIN"
	org_port="SC_${org^^}_P1_PORT"
	[[ -z "${!org_name}" ]] && TEx_Verify 1 "invalid org ${org} "
	TEx_Printf "setting globals for ${!org_name}"

	export ORDERER_CA=${SC_PATH_ORGS}/ordererOrganizations/${SC_ORDERER1_DOMAIN}/tlsca/tlsca.${SC_ORDERER1_DOMAIN}-cert.pem
	export ORDERER_ADMIN_TLS_SIGN_CERT=${SC_PATH_ORGS}/ordererOrganizations/${SC_ORDERER1_DOMAIN}/orderers/${SC_ORDERER1_O1_FQDN}/tls/server.crt
	export ORDERER_ADMIN_TLS_PRIVATE_KEY=${SC_PATH_ORGS}/ordererOrganizations/${SC_ORDERER1_DOMAIN}/orderers/${SC_ORDERER1_O1_FQDN}/tls/server.key

	export CORE_PEER_TLS_ENABLED=true
	export CORE_PEER_LOCALMSPID="${!org_name}MSP"
	export CORE_PEER_TLS_ROOTCERT_FILE=${SC_PATH_ORGS}/peerOrganizations/${!org_domain}/tlsca/tlsca.${!org_domain}-cert.pem
	export CORE_PEER_MSPCONFIGPATH=${SC_PATH_ORGS}/peerOrganizations/${!org_domain}/users/Admin@${!org_domain}/msp
	export CORE_PEER_ADDRESS=localhost:${!org_port}

	TEx_Printf "set orderer variables: $( env | grep ORDERER_ )"
	TEx_Printf "set org variables: $( env | grep CORE )"
}
# [[ -z $BASH ]] || SC_SetGlobals

# endregion: functions
