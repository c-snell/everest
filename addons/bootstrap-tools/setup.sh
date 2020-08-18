#! /bin/bash
set -x

# TOOLS_KUBECTL_VERSION is an env variable that should point to an available
# kubectl binary in this container image. Using that fetch the server
# kubernetes version.
# This should be something like v1.18.1
K8S_VERSION_V=$($TOOLS_KUBECTL_VERSION version -o json | jq -r ".serverVersion.gitVersion")

# Strip the v prefix for consistency elsewhere.
K8S_VERSION="${K8S_VERSION_V##v}"

echo "k8s version to process:$K8S_VERSION"

# Extract major and minor versions
# v1,v2 etc
MAJOR_VER="${K8S_VERSION%%.*}"
REMAINDER="${K8S_VERSION#*.}"
# 14,15,16 etc
START_MINOR_VER="${REMAINDER%%.*}"

echo "MAJOR_VER:$MAJOR_VER, START_MINOR_VER:$START_MINOR_VER"

# Check to see if we have the kubectl binary. If the exact version is
# not present, then reduce the minor version to try again. We will keep
# trying this, until we find a version. kubernetes gurarantees compatibility
# between minor version upto 3 version mismatches. But we are  going
# to relax that go back upto 5 versions.
MINOR_VER=$START_MINOR_VER
while true
do
    FILE_VER="$MAJOR_VER.$MINOR_VER"
    echo "checking for version $FILE_VER*"
    if ls "/usr/local/bin/kubectl-$FILE_VER"* 1> /dev/null 2>&1; then
        cp "/usr/local/bin/kubectl-$MAJOR_VER.$MINOR_VER"* /tools/kubectl
        break
    fi
    MINOR_VER=$(( MINOR_VER - 1 ))
    if [ $(( START_MINOR_VER - MINOR_VER )) -ge 5 ]
    then
        echo "failed to find an appropriate kubectl binary version"
        exit 1
    fi
done

echo "$K8S_VERSION" > /tools/k8s_version

# Copy helm binary
cp /usr/local/bin/helm /tools/helm

# Copy jq tool
cp /usr/local/bin/jq /tools/jq
