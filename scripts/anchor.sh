#!/bin/bash

#
# Copyright TE-FOOD International GmbH., All Rights Reserved
#

[[ ${TEx_COMMON:-"unset"} == "unset" ]] && TEx_COMMON="./common.sh"
if [ ! -f  $TEx_COMMON ]; then
	echo "=> $TEx_COMMON not found, make sure proper path is set or you execute this from the repo's 'scrips' directory!"
	exit 1
fi
source $TEx_COMMON
TEx_PP $TEx_BASE

# org=$1
# peer=$2
# [[ -z "$3" ]] && ch=$SC_CHANNEL_NAME || ch=$3
# # SC_SetGlobalsCLI $1 $2
# # TEx_PrintfBold "setting anchor peer for $SC_SG_PEER_FQDN to $ch"

# SC_FetchChannelConfig

unset ch
