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
# region: functions

fabricChannelCreate_Help() {
	TEx_PrintfBold "TBD"
}

fabricChannelCreate_GenesisBlock() {
	# set -x
	local out=$( configtxgen -profile $SC_CHANNEL_PROFILE -outputBlock "${SC_PATH_ARTIFACTS}/${SC_CHANNEL_NAME}-genesis.block" -configPath "$SC_PATH_CONF" -channelID $SC_CHANNEL_NAME 2>&1 )
	TEx_Verify $? "failed to generate orderer genesis block: $out" "$out"

}

fabricChannelCreate_CreateChannel() {
	local cnt=1
	local res=1
	local out=""
	SC_SetGlobals org1

	TEx_Printf "$SC_CHANNEL_RETRY attempts with ${SC_CHANNEL_DELAY}s safety delay to create channel \"${SC_CHANNEL_NAME}\" is being carried out"
	while [ $res -ne 0 -a $cnt -le $SC_CHANNEL_RETRY ] ; do
		TEx_Printf "attempt #${cnt}"
		TEx_Sleep $SC_CHANNEL_DELAY "${SC_CHANNEL_DELAY}s safety delay"
		out=$( osnadmin channel join --channelID ${SC_CHANNEL_NAME} --config-block "${SC_PATH_ARTIFACTS}/${SC_CHANNEL_NAME}-genesis.block" -o localhost:${SC_ORDERER1_O1_ADMINPORT} --ca-file "$ORDERER_CA" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY" )
		res=$?
		cnt=$(expr $cnt + 1)
		TEx_Printf "osnadmin output ($res): $out"
	done
	TEx_Verify $res "channel creation failed" "channel created successfully"
}


# endregion: functions
# region: getopts

while getopts "h?e:" opt; do
	case "$opt" in
		h | \?)
			fabricChannelCreate_Help
			exit 0
			;;
		e)
			[[ -f $OPTARG ]] || TEx_Verify 1 "env file ($OPTARG) not found"
			source $OPTARG
			;;
	esac
done

# endregion: getopts

# -p	SC_CHANNEL_PROFILE
# -a	SC_PATH_ARTIFACTS
# -c	SC_CHANNEL_NAME
# -C	SC_PATH_CONF
# -r	SC_CHANNEL_RETRY
# -d	SC_CHANNEL_DELAY

# ORDERER_CA
# ORDERER_ADMIN_TLS_SIGN_CERT
# ORDERER_ADMIN_TLS_PRIVATE_KEY
