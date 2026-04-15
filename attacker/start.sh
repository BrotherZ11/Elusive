#!/bin/sh
set -eu

ATTACKER_USER="${ATTACKER_USER:-kali}"
ATTACKER_PASSWORD="${ATTACKER_PASSWORD:-kali}"

if ! id "$ATTACKER_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$ATTACKER_USER"
fi

printf '%s:%s\n' "$ATTACKER_USER" "$ATTACKER_PASSWORD" | chpasswd

mkdir -p /run/sshd /var/run/sshd
ssh-keygen -A

sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?UsePAM .*/UsePAM no/' /etc/ssh/sshd_config

ip route add 172.31.0.0/24 via 172.30.0.2 || true
ip route add 172.32.0.0/24 via 172.30.0.2 || true

echo "[attacker] user=$ATTACKER_USER routes configured"
ip route || true

exec /usr/sbin/sshd -D -e
