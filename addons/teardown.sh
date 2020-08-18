#!/bin/bash
#
# Copyright (c) 2020, HPE Corp.
#
# This script is used to teardown a deployment.
# ./teardown.sh "ADDONNAME"
# ADDONNAME must point to the addon folder that was generated using gen-addons.sh
#
# This script relies on kubectl with the appropriate kubeconfig and admin
# privileges. It will delete configmap,deployment and pvc for a deployment addon
#

source "addon-common.sh"

ADDON="$1"

if ! validate_addon $ADDON; then
    exit 1
fi

source "$ADDON/VERSION"

echo "This script just deletes the bootstrap deployment and configmap"
echo

kubectl -n $NAME delete deployment/$NAME-$ADDON
kubectl -n $NAME delete configmap/$NAME-$ADDON
kubectl -n $NAME delete pvc/$NAME-$ADDON || true

