#!/bin/sh
set -eu

if [ -f /wazuh-config-mount/etc/ossec.conf ]; then
  cp /wazuh-config-mount/etc/ossec.conf /var/ossec/etc/ossec.conf
  chmod 660 /var/ossec/etc/ossec.conf
fi

if [ -f /opt/lab/wazuh/client.keys ]; then
  cp /opt/lab/wazuh/client.keys /var/ossec/etc/client.keys
  chmod 640 /var/ossec/etc/client.keys
fi

exec /init
