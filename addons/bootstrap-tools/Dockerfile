ARG HTTP_PROXY

FROM registry.access.redhat.com/ubi7/ubi-minimal:latest

USER root

ENV https_proxy=$HTTP_PROXY
RUN microdnf update -y && rm -rf /var/cache/yum

RUN microdnf -y install --nodocs curl tar gzip && microdnf clean all

COPY entrypoint /usr/local/bin/entrypoint

ENTRYPOINT ["/usr/local/bin/entrypoint"]

# Update the list to reflect all the kubectl binaries
ARG KUBECTL_VERSIONS="1.14.10 1.15.7 1.16.4 1.17.0 1.18.0"
# When adding new versions to KUBECTL_VERSION, update
# TOOLS_KUBECTL_VERSION to point to the latest version
# This should point to the latest binary
ENV TOOLS_KUBECTL_VERSION="kubectl-1.18.0"

RUN curl -o /usr/local/bin/jq -L https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && \
    chmod +x /usr/local/bin/jq && \
    for VERSION in ${KUBECTL_VERSIONS}; \
    do \
        echo "downloading kubectl version ${VERSION}"; \
        curl -Lo /usr/local/bin/kubectl-${VERSION} https://storage.googleapis.com/kubernetes-release/release/v${VERSION}/bin/linux/amd64/kubectl; \
        chmod +x /usr/local/bin/kubectl-${VERSION}; \
    done
ARG HELM_PACKAGE="helm-v3.2.3-linux-amd64.tar.gz"

RUN curl -o /tmp/${HELM_PACKAGE} -L https://get.helm.sh/${HELM_PACKAGE} && \
    tar xvfz /tmp/${HELM_PACKAGE} -C /tmp/ && \
    cp /tmp/linux-amd64/helm /usr/local/bin/.

ENV https_proxy=""

ADD setup.sh /usr/local/bin/setup.sh
