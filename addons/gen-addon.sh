#!/bin/bash
#

ADDON="$1"
VERSION="$2"

# Name used everywhere in the code. Don't change
NAME="hpecp-bootstrap"
TOOLS_VERSION="0.1"

# Modify this to point to some other chart url
CHART_URL="https://kubernetes-charts.storage.googleapis.com"

if [ -z "$ADDON" ]
then
    echo "specify the name of addon"
    exit 1
fi

if [ -z "$VERSION" ]
then
    echo "specify a version to be used for the addon"
    exit 1
fi

wait_for_prompt() {
    while true; do
        read -rp '    (yes/no) ' user_prompt
        if [ "$user_prompt" == "yes" ] || [ "$user_prompt" == "no" ]
        then
            break
        fi
    done
    echo "$user_prompt"
}

# Must be a dns compliant name.
# TODO. Fix this
echo "$ADDON" | grep -q "[[:space:]]"

if [ $? -eq 0 ]
then
    echo "ADDON parameter ($ADDON) must not contain space characters"
    exit 1
fi

if [ -d "$ADDON" ]
then
    echo "$ADDON directory already exists. do you want to overwrite"
    prompt=$(wait_for_prompt)
    echo
    if [ "$prompt" != "yes" ]
    then
        exit 1
    fi
    echo "All files under $ADDON directory will be deleted. continue"
    prompt=$(wait_for_prompt)
    echo

    if [ "$prompt" != "yes" ]
    then
        exit 1
    fi
    rm -rf $ADDON/*
fi

DEPLOYMENT_FILE="$NAME-$ADDON.yaml"

mkdir -p "$ADDON/"
mkdir -p "$ADDON"/templates

echo "Is python required required for $ADDON image "
PYTHON_REQUIRED=$(wait_for_prompt)
echo

echo "Is $ADDON a helm package "
HELM_PACKAGE=$(wait_for_prompt)
echo

if [ "$HELM_PACKAGE" == "yes" ]
then
    echo "Do you want to setup the chart ($ADDON) package from $CHART_URL "
    CONFIGURE_CHART=$(wait_for_prompt)
    echo
    if [ "$CONFIGURE_CHART" == "yes" ]
    then
        echo -n "checking for helm binary: "
        if ! command -v helm;
        then
            echo "helm 3.X must be installed on the local system."
            exit 1
        fi
        echo
    fi
fi

if [ "$PYTHON_REQUIRED" == "yes" ]
then
    cat > "$ADDON"/Dockerfile <<EOF
ARG HTTP_PROXY

FROM registry.access.redhat.com/ubi7/python-27

USER root

# Set proxy in yum.conf and update
RUN if [[ -n \${HTTP_PROXY} ]]; then echo "proxy=\${HTTP_PROXY}" >> /etc/yum.conf; fi; \
    yum update -y

# Add any additional yum pakages here
#

# yum clean
RUN yum clean all && rm -rf /var/cache/yum /var/tmp/* /tmp/* && \
    sed -i '/^proxy=.*/d' /etc/yum.conf

EOF
else
    cat > "$ADDON"/Dockerfile <<EOF
ARG HTTP_PROXY

FROM registry.access.redhat.com/ubi7/ubi-minimal:latest

USER root

ENV https_proxy=\$HTTP_PROXY
RUN microdnf update -y && rm -rf /var/cache/yum

RUN microdnf -y install --nodocs curl tar \
    && microdnf clean all

ENV https_proxy=""

EOF
fi

cat >> "$ADDON"/Dockerfile <<EOF

COPY entrypoint /usr/local/bin/entrypoint

# In a deployment where a storageclass is available, this folder
# will be from a pvc. Applications must use this for making any
# modifications to templates
RUN mkdir /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint"]

ENV PATH="/tools:\${PATH}"

EOF

if [ "$CONFIGURE_CHART" == "yes" ]
then
    # Fetch helm chart $ADDON and it will be included through
    # templates folder in the container
    echo "fetching helm chart $ADDON.tgz from $CHART_URL"
    helm fetch --repo $CHART_URL "$ADDON" --untar --untardir "$ADDON"/templates
fi

# Include the startscript templates and utility functions
cat >> "$ADDON"/Dockerfile <<EOF
COPY templates/ /templates/

COPY addon-utils /usr/local/bin/addon-utils

COPY startscript /usr/local/bin/startscript
EOF


cat > "$ADDON"/entrypoint <<EOF
#! /bin/bash

mkfifo /tmp/pipe; while true; do cat /tmp/pipe; done
EOF
chmod +x "$ADDON"/entrypoint


cat > "$ADDON"/addon-utils <<EOF
#! /bin/bash

add_service_import() {
    local service_import=\$1
    # test if value is valid json first before attempting any patch
    service_import=\$(jq <<< \$service_import)
    if [ \$? -ne 0 ]; then
        echo "Service import json is invalid."
        return 1
    fi
    local patch="[ {\"op\":\"add\", \"path\": \"/spec/tenantServiceImports/-\", \"value\" : \$service_import} ]"
    kubectl -n hpecp patch hpecpconfig hpecp-global-config --type=json --patch "\$patch"
    return \$?
}

remove_service_import() {
    local service_import=\$1
    service_import=\$(jq <<< \$service_import)
    if [ \$? -ne 0 ]; then
        echo "Service import json is invalid."
        return 1
    fi

    local import_name=\$(jq '.importName' <<< \$service_import)

    # Attempt to specific remove service import and status from hpecp-global-config
    # on conflict, retry after sleeping for increasing periods of N+jitter.
    # where N is (1-30) secs and jitter is a random period of msec up to 1000 (1 second)
    jitter() { shuf -i 0-1000 -n 1; }
    local retries=0 max_backoff=30
    until [ \$retries -eq \$max_backoff ];
    do
        local current_config=\$(kubectl -n hpecp get hpecpconfig hpecp-global-config -o json)
        retries=\$((retries+1))
        # Zero out the status.
        current_config=\$(jq '.status = {}' <<< \$current_config)
        new_config=\$(jq 'del(.spec.tenantServiceImports[] | select(.importName == '\${import_name}'))' <<< \$current_config)
        kubectl apply -f - <<< \$new_config
        [[ \$? -eq 0 ]]  && break || sleep \$retries.\$(jitter)
    done

    if [ \$retries -eq \$max_backoff ]; then
        echo "Failed to remove service import \$import_name"
        return 1
    fi

    echo "Successfully removed service import \$import_name"
    return 0
}
EOF

cat > "$ADDON"/startscript <<EOF
#! /bin/bash
# Let us wait for some time for entrypoint to fire
while ! [ -p /tmp/pipe ]; do sleep 5; done

if grep -wq "true" /etc/bootstrap/debugMode; then
    set -x
else
    exec &>> /tmp/pipe
fi


TEMPLATES_DIR="/templates"
WORKSPACE_DIR="/workspace"
ADDON="$ADDON"
CONFIG_FILE="/etc/bootstrap/config"
VERSION="\$(cat /etc/bootstrap/version)"
FROM_VERSION="\$(cat /etc/bootstrap/from_version)"
K8S_VERSION="\$(cat /tools/k8s_version)"

# source addon utility functions
source /usr/local/bin/addon-utils

# Utility functions to set error and initialize on the deployment configmap
set_deployment_success() {
    kubectl patch configmap/$NAME-\$ADDON --type merge -p '{"data":{"initialize":"false","error":"false"}}'
}

set_deployment_error() {
    kubectl patch configmap/$NAME-\$ADDON --type merge -p '{"data":{"initialize":"false","error":"true"}}'
}

clear_rollback() {
    kubectl patch configmap/$NAME-\$ADDON --type merge -p '{"data":{"rollback":"false"}}'
}

set_reconfigure_success() {
    kubectl patch configmap/$NAME-\$ADDON --type merge -p '{"data":{"reconfigure":"false","error":"false"}}'
}

set_reconfigure_error() {
    kubectl patch configmap/$NAME-\$ADDON --type merge -p '{"data":{"reconfigure":"false","error":"true"}}'
}

set_upgrade_success() {
    kubectl patch configmap/$NAME-\$ADDON --type merge -p '{"data":{"upgrade":"false","error":"false"}}'
}

set_upgrade_error() {
    kubectl patch configmap/$NAME-\$ADDON --type merge -p '{"data":{"upgrade":"false","error":"true"}}'
}

# install related action for deploying the $ADDON
# bdconfig (bds_XXX_YYY) variables are available as environnment variables
# /etc/bootstrap/config files are available through configmap
install() {
    echo "\$(date): Starting $ADDON install process"

    # copy from templates to workspace
    chmod 755 \$WORKSPACE_DIR
    cp -a \$TEMPLATES_DIR/* \$WORKSPACE_DIR

    set_deployment_success
    return 0
}

reconfigure() {
    echo "\$(date): Starting $ADDON reconfigure process"

    set_reconfigure_success
    return 0
}

# TEMPLATES_DIR will have the templates from new image and
# WORKSPACE_DIR will contain the existing modified ones.
# FROM_VERSION will contain the version that we are upgrading from
upgrade() {
    echo "\$(date): Starting $ADDON upgrade process"

    set_upgrade_success
    return 0
}

rollback() {
    echo "\$(date): Starting $ADDON rollback process"

    clear_rollback
    return 0
}

if [ "\$1" == "--install" ]
then
    install
elif [ "\$1" == "--rollback" ]
then
    rollback
elif [ "\$1" == "--reconfigure" ]
then
    reconfigure
elif [ "\$1" == "--upgrade" ]
then
    upgrade
else
    echo "invalid argument"
fi
EOF
chmod +x "$ADDON"/startscript

cat > "$ADDON"/VERSION <<EOF
TOOLS_VERSION=$TOOLS_VERSION
VERSION=$VERSION
EOF

cat > "$ADDON"/README.md <<EOF
Instructions for building $ADDON image and integrating with hcp

# STEP 1
* Make changes to Dockerfile to include any additional packages
* Add any templates files that will be required to bootstrap the application
* Modify install, reconfig and rollback functions in startscript
  - For Helm based applications, modify $NAME-$ADDON configmap in $NAME to include
  values.yaml
  - Change install funtion to use helm install function to install the helm chart
  - Change rollback function to use helm uninstall function
* Build and upload the image

Use build.sh and push.sh to build and push the images. It will use
VERSION file for image version.

For debugging
deploy.sh, rollback.sh, reconfigure.sh and teardown.sh scripts can be used to test the deployment

$NAME-$ADDON configmap can be used for performing any reconfiguration.


# STEP 2
* Create an addon section for the $ADDON in k8s_manifest.json file
* It also has to be included in the list of versions that will be supported
* Use the following as an example. required, system and order must be carefully defined.
  If order is not specified, it will be deployed after all ordered ones are deployed
\`\`\`
$ADDON:
    required: false
    version: "unstable"
    system: false
    order: 1000
    deployment: $NAME-$ADDON.yaml
    label:
      name: "$ADDON"
      description: "$ADDON deployment"
\`\`\`

# STEP 3
Create a symlink of the file $DEPLOYMENT_FILE under <EVEREST_REPO>/install/k8s-addons/
(cd ../../install/k8s-addons; ln -s ../../kubernetes/addons/$ADDON/$DEPLOYMENT_FILE $DEPLOYMENT_FILE)

# STEP 4
Building a new hcp bin file should pick up the new deployment yaml ($DEPLOYMENT_FILE)
EOF

CONFIGMAP="apiVersion: v1
kind: ConfigMap
metadata:
  name: $NAME-$ADDON
  namespace: $NAME
data:
  debugMode: \"false\"
  initialize: \"true\"
  error: \"false\"
  rollback: \"false\"
  reconfigure: \"false\"
  upgrade: \"false\"
  from_version: \"\"
  version: \"\$version\$\"
  config: |-"

# Check to see if values.yaml is present, if so we can add it to the configmap
CONFIG_MAP_VALUES=""
if [ "$CONFIGURE_CHART" == "yes" ] && [ -f "$ADDON/templates/$ADDON/values.yaml" ]
then
    CONFIG_MAP_VALUES=$(sed 's/^/    /g' < "$ADDON/templates/$ADDON/values.yaml")
fi

# Finally generate the deployment template
DEPLOYMENT_COMMON="apiVersion: apps/v1
kind: Deployment
metadata:
  name: $NAME-$ADDON
  namespace: $NAME
spec:
  replicas: 0
  selector:
    matchLabels:
      name: $NAME-$ADDON
  template:
    metadata:
      labels:
        name: $NAME-$ADDON
    spec:
      # This priorityClassName is only supported outside of kube-system in
      # K8s version 1.17.
      #priorityClassName: system-cluster-critical
      tolerations:
        - effect: NoSchedule
          operator: Exists
          key: node-role.kubernetes.io/master
        - key: CriticalAddonsOnly
          operator: Exists
      serviceAccountName: $NAME
      # initContainer is used to copy the kubectl binary and helm binary
      # into a shared emptyDir that the main container can use
      initContainers:
      - name: $ADDON-init
        # Will be replaced by HCP when deploying this deployment
        image: \"\$hpecp_bootstrap_repo\$/$NAME-tools:\$tools_version\$\"
        imagePullPolicy: IfNotPresent
        resources:
          requests:
            memory: 256Mi
            cpu: 250m
          limits:
            memory: 256Mi
            cpu: 250m
        envFrom:
        - configMapRef:
            name: $NAME-bdconfig
        volumeMounts:
          - name: config-volume
            mountPath: /etc/bootstrap
          - name: tools-volume
            mountPath: /tools
        command:
          - \"sh\"
          - \"-c\"
          - |
            /usr/local/bin/setup.sh
      containers:
      - name: $ADDON
        # Will be replaced by HCP when deploying this deployment
        image: \"\$hpecp_bootstrap_repo\$/$NAME-$ADDON:\$version\$\"
        imagePullPolicy: IfNotPresent
        # postStart will launch the startscript based on phase in configmap
        resources:
          requests:
            memory: 256Mi
            cpu: 250m
          limits:
            memory: 256Mi
            cpu: 250m
        lifecycle:
          postStart:
            exec:
              command:
                - \"sh\"
                - \"-c\"
                - |
                  if grep -wq \"true\" /etc/bootstrap/debugMode; then
                    exit 0;
                  fi;
                  if grep -wq \"true\" /etc/bootstrap/initialize; then
                    /usr/local/bin/startscript --install;
                  fi;
                  if grep -wq \"true\" /etc/bootstrap/rollback; then
                    /usr/local/bin/startscript --rollback;
                  fi;
                  if grep -wq \"true\" /etc/bootstrap/reconfigure; then
                    /usr/local/bin/startscript --reconfigure;
                  fi;
                  if grep -wq \"true\" /etc/bootstrap/upgrade; then
                    /usr/local/bin/startscript --upgrade;
                  fi
        envFrom:
        - configMapRef:
            name: $NAME-bdconfig
        volumeMounts:
          - name: tools-volume
            mountPath: /tools
          - name: config-volume
            mountPath: /etc/bootstrap
          - name: workspace-volume
            mountPath: /workspace
      volumes:
        - name: tools-volume
          emptyDir:
            sizeLimit: \"1Gi\"
        - name: config-volume
          configMap:
            defaultMode: 0666
            name: $NAME-$ADDON
        - name: workspace-volume"

cat > "$ADDON/$DEPLOYMENT_FILE" <<EOF
$CONFIGMAP
$CONFIG_MAP_VALUES
---
$DEPLOYMENT_COMMON
          \$workspace_volume_type\$
            \$workspace_volume_info\$
EOF

# Above lines will be replaced by hcp or deploy.sh script
# with following info
# no csi
#          emptyDir:
#            sizeLimit: "1Gi"
# with csi
#          persistentVolumeClaim:
#            claimName: $NAME-$ADDON


echo
echo "Following files/directories are created under $ADDON folder"
echo "Use $ADDON/README.md for instructions to build an image and upload"
ls -l "$ADDON"

echo
echo "A section must be created in k8s_manifest.yaml to include $ADDON as an addon. Refer to $ADDON/README.md"


exit 0
