ARG HTTP_PROXY

FROM registry.access.redhat.com/ubi7/ubi-minimal:latest

USER root

ENV https_proxy=$HTTP_PROXY
RUN microdnf update -y && rm -rf /var/cache/yum

RUN microdnf -y install --nodocs curl tar gzip && microdnf clean all

COPY entrypoint /usr/local/bin/entrypoint

# In a deployment where a storageclass is available, this folder
# will be from a pvc. Applications must use this for making any
# modifications to templates
RUN mkdir /workspace
COPY templates/ /templates/
RUN cd /templates && curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.6.1 sh -
ENV https_proxy=""

ENTRYPOINT ["/usr/local/bin/entrypoint"]

ENV PATH="/tools:${PATH}"

COPY addon-utils /usr/local/bin/addon-utils

COPY startscript /usr/local/bin/startscript
