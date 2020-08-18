#!/bin/bash
#
source "addon-common.sh"

ADDON="tools"

source "bootstrap-tools/VERSION"

docker push $REPO/$NAME-$ADDON:$TOOLS_VERSION
