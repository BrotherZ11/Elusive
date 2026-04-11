FROM wazuh/wazuh-agent:4.14.4

USER root

RUN yum install -y iptables iproute && \
    yum clean all && \
    rm -rf /var/cache/yum
