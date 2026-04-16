#!/bin/sh
set -eu

LOG_DIR=/var/log/firewall
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/events.log"
BLOCK_PAGE_DIR=/opt/lab/firewall/www
BLOCK_PAGE_FILE=/opt/lab/firewall/block.html
COMMAND_DIR=/opt/lab/firewall/state
COMMAND_FILE="$COMMAND_DIR/commands.log"

log() {
  echo "$(date -Iseconds) $1" | tee -a "$LOG_FILE"
}

apply_block() {
  srcip="$1"
  iptables -C INPUT -s "$srcip" -p tcp --dport 8089 -j ACCEPT 2>/dev/null || \
    iptables -I INPUT 1 -s "$srcip" -p tcp --dport 8089 -j ACCEPT || true
  iptables -t nat -C LAB_BLOCK_WEB -s "$srcip" -d 172.31.0.20 -p tcp --dport 80 -j DNAT --to-destination 172.31.0.2:8089 2>/dev/null || \
    iptables -t nat -I LAB_BLOCK_WEB 1 -s "$srcip" -d 172.31.0.20 -p tcp --dport 80 -j DNAT --to-destination 172.31.0.2:8089 || true
  iptables -C LAB_BLOCK -s "$srcip" -j DROP 2>/dev/null || \
    iptables -I LAB_BLOCK 1 -s "$srcip" -j DROP || true
  log "[firewall] blocked $srcip"
}

remove_block() {
  srcip="$1"
  iptables -D INPUT -s "$srcip" -p tcp --dport 8089 -j ACCEPT 2>/dev/null || true
  iptables -t nat -D LAB_BLOCK_WEB -s "$srcip" -d 172.31.0.20 -p tcp --dport 80 -j DNAT --to-destination 172.31.0.2:8089 2>/dev/null || true
  iptables -D LAB_BLOCK -s "$srcip" -j DROP 2>/dev/null || true
  log "[firewall] unblocked $srcip"
}

log "[firewall] enabling IPv4 forwarding"
if [ -w /proc/sys/net/ipv4/ip_forward ]; then
  echo 1 > /proc/sys/net/ipv4/ip_forward || true
fi

if command -v python3 >/dev/null 2>&1 && [ -f "$BLOCK_PAGE_FILE" ]; then
  mkdir -p "$BLOCK_PAGE_DIR"
  cp "$BLOCK_PAGE_FILE" "$BLOCK_PAGE_DIR/index.html"
  python3 -m http.server 8089 --bind 0.0.0.0 -d "$BLOCK_PAGE_DIR" >>"$LOG_DIR/block-page.log" 2>&1 &
  log "[firewall] block page server listening on 8089"
fi

mkdir -p "$COMMAND_DIR"
touch "$COMMAND_FILE"

if command -v iptables >/dev/null 2>&1; then
  iptables -F || true
  iptables -X LAB_BLOCK 2>/dev/null || true
  iptables -t nat -F || true
  iptables -t nat -X LAB_BLOCK_WEB 2>/dev/null || true
  iptables -P INPUT DROP || true
  iptables -P FORWARD DROP || true
  iptables -P OUTPUT ACCEPT || true

  iptables -A INPUT -i lo -j ACCEPT || true
  iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true
  iptables -A INPUT -s 172.30.0.0/24 -p tcp --dport 8089 -j ACCEPT || true
  iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT || true

  iptables -N LAB_BLOCK || true
  iptables -A LAB_BLOCK -j RETURN || true
  iptables -A FORWARD -j LAB_BLOCK || true

  iptables -t nat -N LAB_BLOCK_WEB || true
  iptables -t nat -A PREROUTING -j LAB_BLOCK_WEB || true

  # Only permit representative DMZ access paths from the edge segment.
  iptables -A FORWARD -s 172.30.0.0/24 -d 172.31.0.20 -p icmp --icmp-type echo-request -j ACCEPT || true
  iptables -A FORWARD -s 172.30.0.0/24 -d 172.31.0.30 -p icmp --icmp-type echo-request -j ACCEPT || true
  iptables -A FORWARD -s 172.30.0.0/24 -d 172.31.0.40 -p icmp --icmp-type echo-request -j ACCEPT || true
  iptables -A FORWARD -s 172.30.0.0/24 -d 172.31.0.20 -p tcp --dport 80 -j ACCEPT || true
  iptables -A FORWARD -s 172.30.0.0/24 -d 172.31.0.40 -p tcp --dport 2222 -j ACCEPT || true
  iptables -A FORWARD -s 172.30.0.0/24 -d 172.31.0.30 -p tcp --dport 389 -j ACCEPT || true
  iptables -A FORWARD -s 172.31.0.0/24 -d 172.32.0.0/24 -p tcp -m multiport --dports 80,443,3000,3100,5432,9200,5601,8000 -j ACCEPT || true
fi

tail -n 0 -F "$COMMAND_FILE" | while read -r action srcip; do
  case "$action" in
    add) apply_block "$srcip" ;;
    delete) remove_block "$srcip" ;;
  esac
done &

log "[firewall] interfaces"
ip -br addr | tee -a "$LOG_FILE" || true

log "[firewall] ready"
tail -f /dev/null
