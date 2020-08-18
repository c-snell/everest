#!/bin/bash
#
# Copyright (c) 2020, HPE Corp.
#
# This script is used to deploy an addon on an existing kubernetes cluster.
# ./deploy.sh "ADDONNAME" "DEBUGFLAG"
# ADDONNAME must point to the addon folder that was generated using gen-addons.sh
# DEBUGFLAG is optional. Must be set to true/false. defaults to false.
#
# This script relies on kubectl with the appropriate kubeconfig and admin
# privileges. It will go through the deployment process of an addon and
# will extract the pod logs at the end.
# If DEBUGFLAG is set to true, the script will manually invoke the install function
# After the deployment is completed, pod logs will be collected. If there was
# a successful deployment, the addon deployment will be scaled down, otherwise it will be
# kept running for further testing/debugging
#

source "addon-common.sh"

ADDON="$1"
DEBUG_MODE="$2"

if ! validate_addon $ADDON; then
    exit 1
fi

source "$ADDON/VERSION"

# Debug script that can be used to test the deployment. Prior to running the script
# make sure the system is prepared (namespace, serviceacccounts etc). HCP would have
# done this as part of cluster bootstrapping

# Check if there is a storageclass
if kubectl get storageclass/default; then
cat <<PVEOF | kubectl apply -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: $NAME-$ADDON
  namespace: $NAME
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
PVEOF
    WORKSPACE_VOLUME_TYPE="persistentVolumeClaim:"
    WORKSPACE_VOLUME_INFO="claimName: $NAME-$ADDON"
else
    WORKSPACE_VOLUME_TYPE="emptyDir:"
    WORKSPACE_VOLUME_INFO="sizeLimit: \"1Gi\""
fi

if [ "$DEBUG_MODE" == "true" ]
then
    DEBUG_MODE_OPT="debugMode: \"true\""
    IMAGE_PULL_POLICY=Always
else
    DEBUG_MODE_OPT="debugMode: \"false\""
    IMAGE_PULL_POLICY=IfNotPresent
fi

# Replace repository for the template and replace
# workspace volume type/info along with version
sed -e "s/\$hpecp_bootstrap_repo\\\$/$REPO/g" \
    -e "s/\$tools_version\\\$/$TOOLS_VERSION/g" \
    -e "s/\$workspace_volume_type\\\$/$WORKSPACE_VOLUME_TYPE/g" \
    -e "s/\$workspace_volume_info\\\$/$WORKSPACE_VOLUME_INFO/g" \
    -e "s/debugMode:.*/$DEBUG_MODE_OPT/g" \
    -e "s/: IfNotPresent/: $IMAGE_PULL_POLICY/g" \
    -e "s/\$version\\\$/$VERSION/g" \
    $ADDON/$NAME-$ADDON.yaml | kubectl apply -f -


# Scale replicas to 1
scale_deployment "$ADDON" "1"

echo
Retries=30
while [[ $(kubectl -n $NAME get pods -l name=$NAME-$ADDON -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]
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
    echo "running in debug mode. manually running install function"
    pod_exec "$ADDON" "/usr/local/bin/startscript --install"
    echo
    echo
else
    # Extract logs
    fetch_pod_logs
fi

# Check to see if completed successfully
echo
echo "fetching initialize and error fields from configmap $NAME-$ADDON"
echo
INITIALIZE=$(kubectl -n $NAME  get "configmap/$NAME-$ADDON" -o 'jsonpath={.data.initialize}')
ERROR=$(kubectl -n $NAME  get "configmap/$NAME-$ADDON" -o 'jsonpath={.data.error}')

echo "initialize flag: $INITIALIZE, error flag: $ERROR"

if [ "$INITIALIZE" == "false" ] && [ "$ERROR" == "false" ]
then
    echo "Deployment completed successfully. Scaling down the deployment. To start the pod run "
    echo "kubectl -n $NAME scale deployment/$NAME-$ADDON --replicas=1"

    pod_exec_message "$ADDON"

    scale_deployment "$ADDON" "0"
else
    echo "Deployment failed."
    pod_exec_message "$ADDON"
fi
