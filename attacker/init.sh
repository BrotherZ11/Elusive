#!/bin/sh
set -eu

ip route add 172.31.0.0/24 via 172.30.0.2 || true
ip route add 172.32.0.0/24 via 172.30.0.2 || true

echo "[attacker] routes configured"
ip route || true

tail -f /dev/null
