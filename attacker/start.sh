#!/bin/sh
set -eu

ROOT_PASSWORD="${ROOT_PASSWORD:-root}"

printf 'root:%s\n' "$ROOT_PASSWORD" | chpasswd

mkdir -p /run/sshd /var/run/sshd
ssh-keygen -A

mkdir -p /home/kasm-user/.cache /home/kasm-user/.config /home/kasm-user/.mozilla /home/kasm-user/.vnc
chown -R kasm-user:kasm-user /home/kasm-user/.cache /home/kasm-user/.config /home/kasm-user/.mozilla /home/kasm-user/.vnc
chown kasm-user:kasm-user /home/kasm-user/.Xauthority 2>/dev/null || true

cat <<'EOF' >/usr/local/bin/lab-browser
#!/bin/sh
set -eu

PROFILE_DIR=/home/kasm-user/.mozilla/lab-browser-profile

if [ "$(id -u)" -eq 0 ]; then
  TMP_XAUTH=/tmp/kasm-user.xauth
  cp /home/kasm-user/.Xauthority "$TMP_XAUTH"
  chown kasm-user:kasm-user "$TMP_XAUTH"
  chmod 600 "$TMP_XAUTH"
  mkdir -p "$PROFILE_DIR"
  chown -R kasm-user:kasm-user "$PROFILE_DIR"
  exec su - kasm-user -c "HOME=/home/kasm-user DISPLAY=:1 XAUTHORITY=$TMP_XAUTH firefox-esr --no-sandbox --profile $PROFILE_DIR"
fi

mkdir -p "$PROFILE_DIR"
exec env HOME=/home/kasm-user DISPLAY=:1 XAUTHORITY=/home/kasm-user/.Xauthority firefox-esr --no-sandbox --profile "$PROFILE_DIR"
EOF
chmod +x /usr/local/bin/lab-browser

sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?UsePAM .*/UsePAM yes/' /etc/ssh/sshd_config

ip route add 172.31.0.0/24 via 172.30.0.2 || true
ip route add 172.32.0.0/24 via 172.30.0.2 || true

echo "[attacker] root routes configured"
ip route || true

/usr/sbin/sshd
exec /dockerstartup/vnc_startup.sh
