#!/bin/sh
set -eu

mkdir -p /var/ossec/logs
touch /var/ossec/logs/cowrie-events.jsonl

tail -Fn0 /var/log/cowrie/cowrie.json 2>/dev/null | while IFS= read -r line; do
  eventid="$(printf '%s\n' "$line" | sed -n 's/.*"eventid":"\([^"]*\)".*/\1/p')"
  srcip="$(printf '%s\n' "$line" | sed -n 's/.*"src_ip":"\([^"]*\)".*/\1/p')"

  case "$eventid" in
    cowrie.session.connect)
      if [ -n "$srcip" ]; then
        printf '{"service":"cowrie","eventid":"%s","srcip":"%s"}\n' \
          "$eventid" "$srcip" >> /var/ossec/logs/cowrie-events.jsonl
      fi
      ;;
    cowrie.login.failed|cowrie.login.success)
      username="$(printf '%s\n' "$line" | sed -n 's/.*"username":"\([^"]*\)".*/\1/p')"
      password="$(printf '%s\n' "$line" | sed -n 's/.*"password":"\([^"]*\)".*/\1/p')"

      if [ -n "$srcip" ]; then
        printf '{"service":"cowrie","eventid":"%s","srcip":"%s","username":"%s","password":"%s"}\n' \
          "$eventid" "$srcip" "$username" "$password" >> /var/ossec/logs/cowrie-events.jsonl
      fi
      ;;
  esac
done &

exec /init
