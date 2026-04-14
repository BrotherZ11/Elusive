#!/bin/sh
set -eu

LOG_DIR=/var/log/firewall
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/events.log"

log() {
  echo "$(date -Iseconds) $1" | tee -a "$LOG_FILE"
}

log "[firewall] enabling IPv4 forwarding"
if [ -w /proc/sys/net/ipv4/ip_forward ]; then
  echo 1 > /proc/sys/net/ipv4/ip_forward || true
fi

if command -v iptables >/dev/null 2>&1; then
  iptables -F || true
  iptables -P INPUT DROP || true
  iptables -P FORWARD DROP || true
  iptables -P OUTPUT ACCEPT || true

  iptables -A INPUT -i lo -j ACCEPT || true
  iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true
  iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true

  # Only permit representative DMZ access paths from the edge segment.
  iptables -A FORWARD -s 172.30.0.0/24 -d 172.31.0.20 -p tcp --dport 80 -j ACCEPT || true
  iptables -A FORWARD -s 172.30.0.0/24 -d 172.31.0.40 -p tcp --dport 2222 -j ACCEPT || true
  iptables -A FORWARD -s 172.30.0.0/24 -d 172.31.0.30 -p tcp --dport 389 -j ACCEPT || true
  iptables -A FORWARD -s 172.31.0.0/24 -d 172.32.0.0/24 -p tcp -m multiport --dports 80,443,3000,3100,5432,9200,5601,8000 -j ACCEPT || true
fi

log "[firewall] interfaces"
ip -br addr | tee -a "$LOG_FILE" || true

log "[firewall] ready"
tail -f /dev/null
