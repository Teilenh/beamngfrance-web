#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="localhost/beamng-france-static:local"
CONTAINER="beamng-france-static"
PORT="${PORT:-3000}"
ACTION=start
LABEL="io.beamng-france.project"

case "${1:-}" in
  "") ;;
  --rebuild) ACTION=rebuild ;;
  --stop) ACTION=stop ;;
  -h|--help)
    printf 'Usage: ./start.sh [--rebuild|--stop]\nPORT=3001 ./start.sh pour changer de port.\n'
    exit 0 ;;
  *) printf 'Option inconnue : %s\n' "$1" >&2; exit 2 ;;
esac
(( $# <= 1 )) || { printf 'Trop d’arguments.\n' >&2; exit 2; }

for cmd in podman curl sha256sum; do
  command -v "$cmd" >/dev/null || { printf 'Commande requise : %s\n' "$cmd" >&2; exit 1; }
done
[[ "$PORT" =~ ^[0-9]{1,5}$ ]] && (( 10#$PORT >= 1024 && 10#$PORT <= 65535 )) ||
  { printf 'PORT doit être compris entre 1024 et 65535.\n' >&2; exit 2; }
PORT=$((10#$PORT))
if [[ "$(podman info --format '{{.Host.Security.Rootless}}')" != true ]]; then
  printf 'Podman rootless doit fonctionner avec ton utilisateur (sans sudo).\n' >&2
  exit 1
fi

exists=0
if podman container exists "$CONTAINER"; then
  exists=1
  owner="$(podman inspect --format "{{ index .Config.Labels \"$LABEL\" }}" "$CONTAINER")"
  [[ "$owner" == "$PROJECT_DIR" ]] || {
    printf 'Le conteneur %s ne provient pas de ce projet. Arrêt sans modification.\n' "$CONTAINER" >&2
    exit 1
  }
fi

if [[ "$ACTION" == stop ]]; then
  if (( exists )); then podman stop "$CONTAINER" >/dev/null; fi
  printf 'Site arrêté.\n'
  exit 0
fi

cd "$PROJECT_DIR"
for file in Containerfile nginx.conf site/index.html site/informations-legales/index.html site/styles.css site/app.js site/beammp.js site/assets/logo.png; do
  [[ -f "$file" ]] || { printf 'Fichier manquant : %s\n' "$file" >&2; exit 1; }
done

# Fingerprint only source files, not generated files or dependencies.
fingerprint="$(find site -type f -print0 | sort -z | xargs -0 sha256sum; sha256sum Containerfile nginx.conf .containerignore)"
fingerprint="$(printf '%s' "$fingerprint" | sha256sum | cut -d ' ' -f 1)"
image_hash=""
if podman image exists "$IMAGE"; then
  image_hash="$(podman image inspect --format '{{ index .Labels "io.beamng-france.source" }}' "$IMAGE")"
fi
if [[ "$ACTION" == rebuild || "$image_hash" != "$fingerprint" ]]; then
  printf 'Préparation du site dans le conteneur Nginx…\n'
  podman build --label "io.beamng-france.source=$fingerprint" --tag "$IMAGE" --file Containerfile .
fi
image_id="$(podman image inspect --format '{{.Id}}' "$IMAGE")"

if (( exists )); then
  old_image="$(podman inspect --format '{{.Image}}' "$CONTAINER")"
  old_port="$(podman inspect --format '{{ index .Config.Labels "io.beamng-france.port" }}' "$CONTAINER")"
  if [[ "$old_image" != "$image_id" || "$old_port" != "$PORT" || "$ACTION" == rebuild ]]; then
    # Only this project's disposable container is replaced; there are no data volumes.
    podman rm --force "$CONTAINER" >/dev/null
    exists=0
  fi
fi

if (( exists )); then
  podman start "$CONTAINER" >/dev/null
else
  podman run --detach --name "$CONTAINER" \
    --label "$LABEL=$PROJECT_DIR" --label "io.beamng-france.port=$PORT" \
    --publish "127.0.0.1:$PORT:8080" \
    --cgroups=disabled --read-only --tmpfs /tmp:rw,nosuid,nodev,size=64m \
    --cap-drop all --security-opt no-new-privileges \
    "$IMAGE" >/dev/null
fi

for (( attempt=0; attempt<30; attempt++ )); do
  if [[ "$(podman inspect --format '{{.State.Running}}' "$CONTAINER")" != true ]]; then break; fi
  if curl --noproxy '*' --fail --silent --max-time 2 "http://127.0.0.1:$PORT/" >/dev/null; then
    printf 'BeamNG France : http://localhost:%s/\nArrêter : ./start.sh --stop\n' "$PORT"
    exit 0
  fi
  sleep 1
done
printf 'Le site ne répond pas. Derniers logs :\n' >&2
podman logs --tail 25 "$CONTAINER"
exit 1
