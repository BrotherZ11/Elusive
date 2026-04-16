FROM wazuh/wazuh-agent:4.14.4

USER root

RUN yum install -y iptables iproute ipset python3 && \
    yum clean all && \
    rm -rf /var/cache/yum

COPY firewall-drop.py /var/ossec/active-response/bin/firewall-drop

RUN chmod 750 /var/ossec/active-response/bin/firewall-drop && \
    chown root:wazuh /var/ossec/active-response/bin/firewall-drop
