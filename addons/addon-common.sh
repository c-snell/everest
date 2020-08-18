#! /bin/bash

set -a

NAME="hpecp-bootstrap"
# When using airgap, set this to following
#REPO="bd-harbor1.mip.storage.hpecorp.net:5000/bluedata"
REPO="bluedata"


validate_addon() {
    ADDON="$1"

    # Addon names prefixed with '-' are invalid
    if [[ $ADDON == -* ]]; then
        return 64 #EX_USAGE
    fi

    if [ -z "$ADDON" ]
    then
        echo "specify the name of addon"
        return 1
    fi

    if ! [ -d "$ADDON" ]
    then
        echo "directory $ADDON not found. Use gen-addon.sh to generate a new addon"
        return 1
    fi

    return 0
}

scale_deployment() {
    ADDON="$1"
    REPLICAS="$2"

    kubectl -n $NAME scale "deployment/$NAME-$ADDON" --replicas="$REPLICAS"
}

pod_exec_message() {
    ADDON="$1"
    echo "Use the following command to exec into the pod"
    echo "kubectl -n $NAME exec -it \$(kubectl -n $NAME get -o jsonpath='{.items[0].metadata.name}' pods -l name="$NAME-$ADDON") -c $ADDON -- bash"
}

pod_exec() {
    ADDON="$1"
    shift
    COMMAND="$@"
    kubectl -n $NAME exec -it $(kubectl -n $NAME get -o jsonpath='{.items[0].metadata.name}' pods -l name="$NAME-$ADDON") -c $ADDON -- $COMMAND
}

fetch_pod_logs() {
    echo
    echo
    echo "fetching pod logs"
    POD_NAME=$(kubectl -n $NAME get -o jsonpath='{.items[0].metadata.name}' pods -l name="$NAME-$ADDON")
    kubectl -n $NAME logs $POD_NAME
    echo
}
