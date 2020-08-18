ARG HTTP_PROXY

FROM registry.access.redhat.com/ubi7/ubi-minimal:latest

USER root

ENV https_proxy=$HTTP_PROXY
RUN microdnf update -y && rm -rf /var/cache/yum

RUN microdnf -y install --nodocs curl tar     && microdnf clean all

ENV https_proxy=""


COPY entrypoint /usr/local/bin/entrypoint

# In a deployment where a storageclass is available, this folder
# will be from a pvc. Applications must use this for making any
# modifications to templates
RUN mkdir /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint"]

ENV PATH="/tools:${PATH}"

COPY templates/ /templates/

COPY startscript /usr/local/bin/startscript
