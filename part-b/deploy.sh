#!/usr/bin/env bash
set -euo pipefail

PART_B_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$PART_B_DIR/VERSION"
API_DIR="$PART_B_DIR/api"
K8S_DIR="$PART_B_DIR/k8s"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "Version file not found: $VERSION_FILE" >&2
  exit 1
fi

VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
if [[ "$VERSION" != "v1" && "$VERSION" != "v2" && "$VERSION" != "v3" ]]; then
  echo "Unsupported version '$VERSION'. Set part-b/VERSION to v1, v2, or v3." >&2
  exit 1
fi

IMAGE="docker.io/library/fortune-api:$VERSION"
IMAGE_ARCHIVE="$(mktemp "${TMPDIR:-/tmp}/fortune-api-${VERSION}.XXXXXX.tar")"
DEPLOYMENT_MANIFEST="$(mktemp "${TMPDIR:-/tmp}/fortune-api-deployment.XXXXXX.yaml")"
trap 'rm -f "$IMAGE_ARCHIVE" "$DEPLOYMENT_MANIFEST"' EXIT

sudo podman build --format docker --build-arg "APP_VERSION=$VERSION" \
  -t "$IMAGE" "$API_DIR"
sudo podman save --format docker-archive -o "$IMAGE_ARCHIVE" "$IMAGE"
sudo k3s ctr -n k8s.io images import "$IMAGE_ARCHIVE"

sed \
  -e "s|image: fortune-api:v1|image: $IMAGE|" \
  -e "s|value: v1|value: $VERSION|" \
  "$K8S_DIR/fortune-api-deployment.yaml" > "$DEPLOYMENT_MANIFEST"

sudo k3s kubectl apply -f "$K8S_DIR/fortune-api-service.yaml"
sudo k3s kubectl apply -f "$DEPLOYMENT_MANIFEST"
sudo k3s kubectl rollout status deployment/fortune-api --timeout=180s
sudo k3s kubectl get pods -l app=fortune-api

echo "Deployed Fortune API $VERSION."
