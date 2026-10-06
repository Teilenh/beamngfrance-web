#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SITE_SOURCE="$PROJECT_DIR/site"
SITE_TARGET="/var/www/beamng-france"
ACTION="${1:-install}"

case "$ACTION" in
  install|--restart|--stop) ;;
  -h|--help)
    printf 'Usage: ./start.sh [--restart|--stop]\n'
    exit 0 ;;
  *) printf 'Option inconnue : %s\n' "$ACTION" >&2; exit 2 ;;
esac
(( $# <= 1 )) || { printf 'Trop d’arguments.\n' >&2; exit 2; }

[[ $EUID -eq 0 ]] || {
  printf 'Ce script doit être lancé en root, directement ou avec sudo.\n' >&2
  exit 1
}
[[ -f "$PROJECT_DIR/nginx.conf" && -f "$SITE_SOURCE/index.html" ]] || {
  printf 'nginx.conf ou site/index.html est manquant.\n' >&2
  exit 1
}

service_action() {
  local command="$1"

  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
    if [[ "$command" == enable ]]; then
      systemctl enable nginx
      systemctl restart nginx
    else
      systemctl "$command" nginx
    fi
  elif command -v rc-service >/dev/null 2>&1; then
    if [[ "$command" == enable ]]; then
      rc-update add nginx default >/dev/null
      rc-service nginx restart || rc-service nginx start
    else
      rc-service nginx "$command"
    fi
  else
    case "$command" in
      enable|restart) nginx -s reload 2>/dev/null || nginx ;;
      stop) nginx -s stop ;;
    esac
  fi
}

if [[ "$ACTION" == --stop ]]; then
  command -v nginx >/dev/null 2>&1 || { printf 'Nginx n’est pas installé.\n'; exit 0; }
  service_action stop
  printf 'Site arrêté.\n'
  exit 0
fi

if ! command -v nginx >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 \
  || [[ ! -f /etc/ssl/certs/ca-certificates.crt ]]; then
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    env DEBIAN_FRONTEND=noninteractive apt-get install -y nginx ca-certificates curl
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache nginx ca-certificates curl
  else
    printf 'Système non pris en charge. Installe nginx, ca-certificates et curl manuellement.\n' >&2
    exit 1
  fi
fi

if [[ -d /etc/nginx/http.d ]]; then
  NGINX_TARGET="/etc/nginx/http.d/beamng-france.conf"
  [[ ! -f /etc/nginx/http.d/default.conf ]] \
    || mv /etc/nginx/http.d/default.conf /etc/nginx/http.d/default.conf.disabled
else
  NGINX_TARGET="/etc/nginx/conf.d/beamng-france.conf"
  if [[ -L /etc/nginx/sites-enabled/default ]]; then
    unlink /etc/nginx/sites-enabled/default
  fi
fi

install -d -m 0755 "$SITE_TARGET"
cp -a "$SITE_SOURCE/." "$SITE_TARGET/"
install -m 0644 "$PROJECT_DIR/nginx.conf" "$NGINX_TARGET"

nginx -t
if [[ "$ACTION" == --restart ]]; then
  service_action restart
else
  service_action enable
fi

for _ in {1..15}; do
  if curl --noproxy '*' --fail --silent --max-time 2 "http://127.0.0.1/" >/dev/null; then
    printf 'BeamNG France est disponible sur http://%s/\n' "$(hostname -I 2>/dev/null | awk '{print $1}')"
    exit 0
  fi
  sleep 1
done

printf 'Nginx fonctionne, mais le site ne répond pas sur le port 80.\n' >&2
exit 1
