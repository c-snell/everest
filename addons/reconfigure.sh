#!/bin/bash
#
# Copyright (c) 2020, HPE Corp.
#
# This script is used to reconfigure an addon on an existing kubernetes cluster.
# ./reconfigure.sh "ADDONNAME" "DEBUGFLAG"
# ADDONNAME must point to the addon folder that was generated using gen-addons.sh
# DEBUGFLAG is optional. Must be set to true/false. defaults to false.
#
# This script relies on kubectl with the appropriate kubeconfig and admin
# privileges. It will go through the reconfigure process of an addon and
# will extract the pod logs at the end.
# If DEBUGFLAG is set to true, the script will manually invoke the reconfigure function
# After the reconfigure is completed, pod logs will be collected. If there was
# a successful reconfigure, the addon deployment will be scaled down, otherwise it will be
# kept running for further testing/debugging
#

source "addon-common.sh"

ADDON="$1"
DEBUG_MODE="$2"

if ! validate_addon $ADDON; then
    exit 1
fi

source "$ADDON/VERSION"

# Set replica count to 0
scale_deployment "$ADDON" "0"

# Set reconfigure flag
if [ "$DEBUG_MODE" == "true" ]
then
    kubectl -n $NAME patch configmap/$NAME-$ADDON --type merge -p '{"data":{"debugMode":"true","initialize":"false","reconfigure":"true","error":"false"}}'
else
    kubectl -n $NAME patch configmap/$NAME-$ADDON --type merge -p '{"data":{"debugMode":"false","initialize":"false","reconfigure":"true","error":"false"}}'
fi

# Restart the pod
scale_deployment "$ADDON" "1"

echo
Retries=30
while [[ $(kubectl -n $NAME get pods -l name=$NAME-$ADDON -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]] && [ $Retries -gt 0 ]
do
    echo "Waiting for $NAME-$ADDON to be running"
    Retries=$(( Retries - 1 ))
    if [[ "$Retries" -le 0 ]]; then
        echo "Failed waiting for to $NAME-$ADDON to be running."
        exit 1
    fi
    sleep 10
done

if [ "$DEBUG_MODE" == "true" ]
then
    echo "running in debug mode. manually running reconfigure function"
    pod_exec "$ADDON" "/usr/local/bin/startscript --reconfigure"
else
    echo "fetching pod logs"
    fetch_pod_logs
fi

# Check to see if completed successfully
echo
echo "fetching reconfigure and error fields from configmap $NAME-$ADDON"
echo
RECONFIGURE=$(kubectl -n $NAME get "configmap/$NAME-$ADDON" -o 'jsonpath={.data.reconfigure}')
ERROR=$(kubectl -n $NAME get "configmap/$NAME-$ADDON" -o 'jsonpath={.data.error}')

if [ "$RECONFIGURE" == "false" ] && [ "$ERROR" == "false" ]
then
    echo "Reconfigure completed successfully. Scaling down the deployment. To start the pod run "
    echo "kubectl -n $NAME scale deployment/$NAME-$ADDON --replicas=1"

    echo "After bringing the pod up, use the following command to exec into the pod"
    echo $'kubectl -n $NAME exec -it $(kubectl -n $NAME get -o jsonpath='{.items[0].metadata.name}' pods -l name="$NAME-$ADDON") -c $ADDON -- bash'

    kubectl -n $NAME scale deployment/$NAME-$ADDON --replicas=0
else
    echo "Reconfigure failed."
    # You can exec into the pod by running the following command
    echo "For debugging, exec into the pod using the following command"
    echo "kubectl -n $NAME exec -it \"$POD_NAME\" -c $ADDON -- bash"
fi

