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

#

re='^[0-9]+$'
port="$1"
[[ -z $port ]] && port=5055
[[ $port =~ $re ]] || TEx_Verify 1 "usage: $0 [optional port, must be a number]"

#

_logspout() {
	docker kill logspout 2> /dev/null 1>&2 || true
	docker rm logspout 2> /dev/null 1>&2 || true

	trap "docker kill logspout" SIGINT

	docker run -d --rm --name="logspout"					\
		--volume=/var/run/docker.sock:/var/run/docker.sock	\
 		--publish=127.0.0.1:${port}:80						\
	 	gliderlabs/logspout

	TEx_Sleep 3
}
TEx_YN "spin up logspout?" _logspout

curl http://127.0.0.1:${port}/logs

unset re
unset port
