#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

# region: load common

[[ ${TEx_COMMON:-"unset"} == "unset" ]] && TEx_COMMON="./common.sh"
if [ ! -f  $TEx_COMMON ]; then
	echo "=> $TEx_COMMON not found, make sure proper path is set or you execute this from the repo's 'scrips' directory!"
	exit 1
fi
source $TEx_COMMON
TEx_PP $TEx_BASE

# endregion: load common
# region: defaults

TEx_FabricChannelCreate_Defaults() {
	caFile=$ORDERER_CA
	clientCert=$ORDERER_ADMIN_TLS_SIGN_CERT
	clientKey=$ORDERER_ADMIN_TLS_PRIVATE_KEY
	channelID=""
	configPath=$TEx_BASE
	configBlockFile="genesis.block"
	configBlock="${configPath}/${configPathFile}"
	delay=3
	dummy=$TEx_DUMMY
	profile="TwoOrgsApplicationGenesis"
	retry=5
}
TEx_FabricChannelCreate_Defaults

# endregion: defaults
# region: help

fabricChannelCreate_Help() {
	TEx_Printf "usage:"
	TEx_Printf "  $0 <options>"
	TEx_Printf ""
	TEx_Printf "options:"
	TEx_Printf "  -a, --clientCert <file>    file containing PEM-encoded X509 public key to use for mutual TLS communication with the OSN, falls back to \$ORDERER_ADMIN_TLS_SIGN_CERT"
	TEx_Printf "  -A, --clientKey <file>     file containing PEM-encoded private key to use for mutual TLS communication with the OSN, falls back to \$ORDERER_ADMIN_TLS_PRIVATE_KEY" 
	TEx_Printf "  -c, --channelID <string>   channel name to be created"
	TEx_Printf "  -C, --configPath <path>    path containing the configuration (configtx.yaml), falls back to \$TEx_BASE"
	TEx_Printf "  -d, --dummy                dummy mode, commands will not be executed, falls back to \$TEx_DUMMY"
	TEx_Printf "  -D, --delay <int>          delay between attempts, default: $delay"
	TEx_Printf "  -e, --env <file>           env file to load before execution" 
	TEx_Printf "  -g, --configBlock <file>   path to genesis block, falls back to --configPath/${configBlockFile}"
	TEx_Printf "  -h, --help                 print this message"
	TEx_Printf "  -o, --caFile <file>        path to file containing PEM-encoded TLS CA certificate(s) for the OSN, falls back to \$ORDERER_CA"
	TEx_Printf "  -p, --profile <file>       profile from configtx.yaml to use for genesis block generation, default: $profile"
	TEx_Printf "  -r, --retry <int>          number of max retryes, default: $retry"
	TEx_Printf ""
	TEx_Printf "- all paths are either absolute or relative to TEx_BASE (currently \"$TEx_BASE\")"
	TEx_Printf "- all parameters must have a value, except where there is a default or fallback"
}

# endregion: help
# region: getopt

opts="a:A:c:C:dD:e:g:ho:p:r:"
lopts="clientCert:,clientKey:,channelID:,configPath:,dummy,delay:,env:,configBlock:,help,caFile:,profile:,retry:"
args=$( getopt -n $0 -o "$opts" -l "$lopts" -a -Q -- "$@" 2>&1 )
if [ $? -ne 0 ]; then
	TEx_PrintfBold "$args"
	fabricChannelCreate_Help
	TEx_Verify 1
fi
args=$( getopt -n $0 -o "$opts" -l "$lopts" -a -q -- "$@" )
eval set -- "$args"
unset opts lopts

# endregion: getopt
# region: parse $@ and validate

checkDir()  { [[ -d "$2" ]] || TEx_Verify 1 "the directory specified by '$1 $2' is cannot be accessed"; }
checkFile() { [[ -f "$2" ]] || TEx_Verify 1 "the file specified by '$1 $2' is cannot be accessed"; }
checkInt()  { [[ $2 =~ ^[0-9]+$ ]] || TEx_Verify 1 "argument must be an integer in \"$1 $2\""; }

while [ : ]; do
	echo $1
	case "$1" in
		-e | --env)
			checkFile "$@"
			[[ -f $2 ]] && out=$( source $2 2>&1 )
			[[ $? -ne 0 ]] && TEx_Verify 1 "unable to source ${2}: ${out}" || source $2 
			shift 2
			unset out
			TEx_FabricChannelCreate_Defaults
			;;
		--)
			shift
			break
			;;
		-*)
			shift
			;;
	esac
done

eval set -- "$args"
unset args

while [ : ]; do
	case "$1" in
		-a | --clientCert)
			checkFile "$@"
			clientCert="$2"
			shift 2
			;;
		-A | --clientKey)
			checkFile "$@"
			clientKey="$2"
			shift 2
			;;
		-c | --channelID)
			channelID="$2"
			shift 2
			;;
		-C | --configPath)
			checkDir "$@"
			configPath="$2"
			shift 2
			;;
		-d | --dummy)
			TEx_DUMMY=true
			shift
			;;
		-D | --delay)
			checkInt "$@"
			delay=$2
			shift 2
			;;
		-e | --env)
		# 	checkFile "$@"
		# 	[[ -f $2 ]] && out=$( source $2 2>&1 )
		# 	[[ $? -ne 0 ]] && TEx_Verify 1 "unable to source ${2}:${out}" || source $2 
		# 	unset out
			shift 2
			;;
		-g | --configBlock)
			checkDir "$1" "$(dirname "$2")"
			configBlock="$2"
			shift 2
			;;
		-h | --help)
			fabricChannelCreate_Help
			exit 0
			;;
		-o | --caFile)
			checkFile "$@"
			caFile="$2"
			shift 2
			;;
		-p | --profile)
			profile="$2"
			shift 2
			;;
		-r | --retry)
			checkInt "$@"
			retry=$2
			shift 2
			;;
		--)
			shift
			break
			;;
		-*)
			TEx_Verify 1 "$0: error - unrecognized option $1"
			shift
			;;
		*)
			break
			;;
	esac
done

checkDir()  { [[ -d "$2" ]] || TEx_Verify 1 "'$2' cannot be accessed, set proper value with '$1'"; }
checkFile() { [[ -f "$2" ]] || TEx_Verify 1 "'$2' cannot be accessed, set proper value by '$1'"; }

# caFile=$ORDERER_CA
# clientCert=$ORDERER_ADMIN_TLS_SIGN_CERT
# clientKey=$ORDERER_ADMIN_TLS_PRIVATE_KEY
# channelID=""
# configPath=$TEx_BASE
# configBlock="${configPath}/${configPathFile}"

if [ "$TEx_DUMMY" != true ]; then
	checkFile "--clientCert" "$clientCert"
fi

unset checkDir checkFile checkInt

# endregion: parse and validate
# region: actual bussines

TEx_FabricChannelCreate_GenesisBlock() {
	# local out=$( configtxgen -profile $SC_CHANNEL_PROFILE -outputBlock "${SC_PATH_ARTIFACTS}/${SC_CHANNEL_NAME}-genesis.block" -configPath "$SC_PATH_CONF" -channelID $SC_CHANNEL_NAME 2>&1 )
	TEx_Verify $? "failed to generate orderer genesis block: $out" "$out"
}

TEx_FabricChannelCreate_CreateChannel() {
	# local cnt=1
	# local res=1
	# local out=""
	# SC_SetGlobals org1

	# TEx_Printf "$SC_CHANNEL_RETRY attempts with ${SC_CHANNEL_DELAY}s safety delay to create channel \"${SC_CHANNEL_NAME}\" is being carried out"
	# while [ $res -ne 0 -a $cnt -le $SC_CHANNEL_RETRY ] ; do
	# 	TEx_Printf "attempt #${cnt}"
	# 	TEx_Sleep $SC_CHANNEL_DELAY "${SC_CHANNEL_DELAY}s safety delay"
	# 	out=$( osnadmin channel join --channelID ${SC_CHANNEL_NAME} --config-block "${SC_PATH_ARTIFACTS}/${SC_CHANNEL_NAME}-genesis.block" -o localhost:${SC_ORDERER1_O1_ADMINPORT} --ca-file "$ORDERER_CA" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY" )
	# 	res=$?
	# 	cnt=$(expr $cnt + 1)
	# 	TEx_Printf "osnadmin output ($res): $out"
	# done
	TEx_Verify $res "channel creation failed" "channel created successfully"
}

# endregion: actual
# region: closing provisions

TEx_DUMMY=$dummy

# endregion: closing
