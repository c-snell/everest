ARG HTTP_PROXY

FROM registry.access.redhat.com/ubi7/python-27

USER root

# Set proxy in yum.conf and update
RUN if [[ -n ${HTTP_PROXY} ]]; then echo "proxy=${HTTP_PROXY}" >> /etc/yum.conf; fi;     yum update -y

# Add any additional yum pakages here
#

# yum clean
RUN yum clean all && rm -rf /var/cache/yum /var/tmp/* /tmp/* &&     sed -i '/^proxy=.*/d' /etc/yum.conf


COPY entrypoint /usr/local/bin/entrypoint

# In a deployment where a storageclass is available, this folder
# will be from a pvc. Applications must use this for making any
# modifications to templates
RUN mkdir /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint"]

ENV PATH="/tools:${PATH}"

COPY templates/ /templates/

COPY startscript /usr/local/bin/startscript
