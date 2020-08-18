#!/bin/bash
#

ADDON="$1"
ADDON_TASK="$2"

source "addon-common.sh"

validate (){
    if ! validate_addon $ADDON; then
        exit 1
    fi    
}

build () {
    if [[ -n ${HTTP_PROXY} ]];
    then
        ADDITIONAL_ARGS="${ADDITIONAL_ARGS} --build-arg=HTTP_PROXY=${HTTP_PROXY}"
    elif [[ -n ${http_proxy} ]];
    then
        ADDITIONAL_ARGS="${ADDITIONAL_ARGS} --build-arg=HTTP_PROXY=${http_proxy}"
    fi
    
    if [[ $ADDON ==  "tools" ]];
    then
        source "bootstrap-tools/VERSION"
        docker build ${ADDITIONAL_ARGS} -t $REPO/$NAME-$ADDON:$TOOLS_VERSION bootstrap-tools
    else
        validate
        source "$ADDON/VERSION"
        docker build ${ADDITIONAL_ARGS} -t $REPO/$NAME-$ADDON:$VERSION $ADDON
    fi

}

push () {
    if [[ $ADDON ==  "tools" ]];
    then
        source "bootstrap-tools/VERSION"
        docker push $REPO/$NAME-$ADDON:$TOOLS_VERSION
    else
        validate
        source "$ADDON/VERSION"
        docker push $REPO/$NAME-$ADDON:$VERSION
    fi
}


if [[ "$ADDON_TASK" == 'build' ]];
then
    build
elif [[ "$ADDON_TASK" == 'push' ]];
then
    push
else
    echo "Usage ./addon.sh <ADDON-NAME> <build/push> as arguments"
    echo "example- tools build: ./addon.sh tools build"
    echo "example- addon push: ./addon.sh addon-name build or push"
fi