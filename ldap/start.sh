#!/bin/sh
set -eu

mkdir -p /var/log/ldap
touch /var/log/ldap/slapd.log /var/log/ldap/events.jsonl
mkdir -p /tmp/ldap-conn-map
rm -f /tmp/ldap-conn-map/*

 /container/tool/run > /var/log/ldap/slapd.log 2>&1 &

SLAPD_PID=$!

tail -F /var/log/ldap/slapd.log | while IFS= read -r line; do

  printf '%s\n' "$line"

  accept_conn="$(printf '%s\n' "$line" | awk '/ACCEPT from IP=/{for (i=1;i<=NF;i++) if ($i ~ /^conn=/){sub(/^conn=/,"",$i); print $i; exit}}')"
  accept_ip="$(printf '%s\n' "$line" | awk '/ACCEPT from IP=/{for (i=1;i<=NF;i++) if ($i ~ /^IP=/){sub(/^IP=/,"",$i); sub(/:.*/,"",$i); print $i; exit}}')"

  if [ -n "$accept_conn" ] && [ -n "$accept_ip" ]; then
    printf '%s' "$accept_ip" > "/tmp/ldap-conn-map/$accept_conn"
  fi

  if printf '%s\n' "$line" | tr '[:upper:]' '[:lower:]' | grep -q 'filter="(cn=soc-admin)"'; then
    search_conn="$(printf '%s\n' "$line" | sed -n 's/.*conn=\([0-9][0-9]*\).*/\1/p')"

    if [ -n "$search_conn" ] && [ -f "/tmp/ldap-conn-map/$search_conn" ]; then
      search_ip="$(cat "/tmp/ldap-conn-map/$search_conn")"

      if [ "$search_ip" != "127.0.0.1" ]; then
        printf '{"service":"ldap-honeytoken","srcip":"%s","conn":"%s","indicator":"SOC-admin"}\n' "$search_ip" "$search_conn" >> /var/log/ldap/events.jsonl
      fi
    fi
  fi

done

wait $SLAPD_PID