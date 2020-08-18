#!/bin/bash
#

source "addon-common.sh"

ADDON="tools"

source "bootstrap-tools/VERSION"

if [[ -n ${HTTP_PROXY} ]];
then
    ADDITIONAL_ARGS="${ADDITIONAL_ARGS} --build-arg=HTTP_PROXY=${HTTP_PROXY}"
elif [[ -n ${http_proxy} ]];
then
    ADDITIONAL_ARGS="${ADDITIONAL_ARGS} --build-arg=HTTP_PROXY=${http_proxy}"
fi

docker build ${ADDITIONAL_ARGS} -t $REPO/$NAME-$ADDON:$TOOLS_VERSION bootstrap-tools
