#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER="beamng-france-static"
IMAGE="docker.io/nginxinc/nginx-unprivileged:stable-alpine"
LABEL="io.beamng-france.project"
ACTION="${1:-start}"

case "$ACTION" in
  start|--restart|--stop) ;;
  -h|--help)
    printf 'Usage: ./start.sh [--restart|--stop]\n'
    exit 0 ;;
  *) printf 'Option inconnue : %s\n' "$ACTION" >&2; exit 2 ;;
esac
(( $# <= 1 )) || { printf 'Trop d’arguments.\n' >&2; exit 2; }

command -v podman >/dev/null || { printf 'Podman est requis.\n' >&2; exit 1; }
command -v curl >/dev/null || { printf 'curl est requis.\n' >&2; exit 1; }
[[ "$(podman info --format '{{.Host.Security.Rootless}}')" == true ]] || {
  printf 'Podman doit fonctionner en mode rootless, sans sudo.\n' >&2
  exit 1
}
[[ -f "$PROJECT_DIR/nginx.conf" && -f "$PROJECT_DIR/site/index.html" ]] || {
  printf 'nginx.conf ou site/index.html est manquant.\n' >&2
  exit 1
}

if [[ "$ACTION" == --stop ]]; then
  if podman container exists "$CONTAINER"; then
    podman stop "$CONTAINER" >/dev/null
  fi
  printf 'Site arrêté.\n'
  exit 0
fi

if podman container exists "$CONTAINER"; then
  owner="$(podman inspect --format "{{ index .Config.Labels \"$LABEL\" }}" "$CONTAINER")"
  site_mount="$(podman inspect --format '{{ range .Mounts }}{{ if eq .Destination "/usr/share/nginx/html" }}{{ .Source }}{{ end }}{{ end }}' "$CONTAINER")"
  config_mount="$(podman inspect --format '{{ range .Mounts }}{{ if eq .Destination "/etc/nginx/conf.d/default.conf" }}{{ .Source }}{{ end }}{{ end }}' "$CONTAINER")"
  [[ "$owner" == "$PROJECT_DIR" || ( -z "$owner" && "$site_mount" == "$PROJECT_DIR/site" && "$config_mount" == "$PROJECT_DIR/nginx.conf" ) ]] || {
    printf 'Le conteneur %s ne provient pas de ce projet. Arrêt sans modification.\n' "$CONTAINER" >&2
    exit 1
  }
  if [[ "$ACTION" == --restart ]]; then
    podman restart "$CONTAINER" >/dev/null
  else
    podman start "$CONTAINER" >/dev/null
  fi
else
  podman run --detach --name "$CONTAINER" --pull=missing \
    --label "$LABEL=$PROJECT_DIR" \
    --publish "127.0.0.1:3000:8080" \
    --volume "$PROJECT_DIR/site:/usr/share/nginx/html:ro,Z" \
    --volume "$PROJECT_DIR/nginx.conf:/etc/nginx/conf.d/default.conf:ro,Z" \
    --cgroups=disabled --read-only --tmpfs /tmp:rw,nosuid,nodev,size=64m \
    --cap-drop all --security-opt no-new-privileges \
    "$IMAGE" >/dev/null
fi

for _ in {1..15}; do
  if curl --noproxy '*' --fail --silent --max-time 2 "http://127.0.0.1:3000/" >/dev/null; then
    printf 'BeamNG France : http://localhost:3000/\nArrêter : ./start.sh --stop\n'
    exit 0
  fi
  sleep 1
done

printf 'Le site ne répond pas. Derniers logs :\n' >&2
podman logs --tail 20 "$CONTAINER" >&2
exit 1
