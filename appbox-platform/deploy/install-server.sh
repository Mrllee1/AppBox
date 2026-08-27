#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run this installer as root." >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

for command_name in node npm nginx systemctl; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 3
  fi
done

if ! id appbox >/dev/null 2>&1; then
  useradd --system --home /var/lib/appbox --shell /usr/sbin/nologin appbox
fi

install -d -m 0755 -o appbox -g appbox /var/lib/appbox
install -d -m 0750 -o appbox -g appbox /var/lib/appbox/assets
install -d -m 0755 -o appbox -g appbox /var/lib/appbox/downloads
install -d -m 0750 -o root -g appbox /etc/appbox
install -d -m 0755 -o root -g root /var/www/appbox-acme/.well-known/acme-challenge

if [[ ! -f /etc/appbox/appbox.env ]]; then
  install -m 0640 -o root -g appbox "$SCRIPT_DIR/appbox.env.example" /etc/appbox/appbox.env
  echo "Created /etc/appbox/appbox.env. Replace all placeholder secrets, then run this installer again." >&2
  exit 4
fi

cd "$PLATFORM_DIR"
npm ci
npm run build

sed "s|__APPBOX_PLATFORM_DIR__|$PLATFORM_DIR|g" \
  "$SCRIPT_DIR/appbox-api.service.template" >/etc/systemd/system/appbox-api.service
sed "s|__APPBOX_PLATFORM_DIR__|$PLATFORM_DIR|g" \
  "$SCRIPT_DIR/appbox-admin.service.template" >/etc/systemd/system/appbox-admin.service
nginx_config="$SCRIPT_DIR/nginx-appbox.conf"
if [[ -f /etc/letsencrypt/live/3601.help/fullchain.pem ]]; then
  nginx_config="$SCRIPT_DIR/nginx-appbox-https.conf"
fi
install -m 0644 "$nginx_config" /etc/nginx/sites-available/appbox
ln -sfn /etc/nginx/sites-available/appbox /etc/nginx/sites-enabled/appbox
if [[ -L /etc/nginx/sites-enabled/default ]]; then
  unlink /etc/nginx/sites-enabled/default
fi

nginx -t
systemctl daemon-reload
systemctl enable --now appbox-api.service appbox-admin.service nginx
systemctl restart appbox-api.service appbox-admin.service nginx

health_ready=0
for _ in {1..30}; do
  if curl --fail --silent --show-error http://127.0.0.1/health; then
    health_ready=1
    break
  fi
  sleep 1
done
if [[ "$health_ready" -ne 1 ]]; then
  echo "AppBox API did not become healthy within 30 seconds." >&2
  exit 5
fi
echo
echo "APPBOX_SERVER_OK"
