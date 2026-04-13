#!/bin/sh
set -eu

if [ -f /opt/lab/wazuh/client.keys ]; then
  cp /opt/lab/wazuh/client.keys /var/ossec/etc/client.keys
  chmod 640 /var/ossec/etc/client.keys
fi

exec /init
