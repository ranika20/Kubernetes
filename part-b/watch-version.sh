#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PART_B_DIR="${FORTUNE_API_PROJECT_DIR:-$SCRIPT_DIR}"
VERSION_FILE="$PART_B_DIR/VERSION"
DEPLOY_SCRIPT="$SCRIPT_DIR/deploy.sh"
LAST_ATTEMPTED_VERSION=""

while true; do
  if [[ -r "$VERSION_FILE" ]]; then
    VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"

    if [[ "$VERSION" == "v1" || "$VERSION" == "v2" || "$VERSION" == "v3" || "$VERSION" == "v4" ]]; then
      DEPLOYED_VERSION="$(sudo k3s kubectl get deployment fortune-api \
        -o 'jsonpath={.spec.template.spec.containers[?(@.name=="api")].env[?(@.name=="APP_VERSION")].value}' \
        2>/dev/null || true)"

      if [[ "$VERSION" != "$DEPLOYED_VERSION" && "$VERSION" != "$LAST_ATTEMPTED_VERSION" ]]; then
        echo "[$(date --iso-8601=seconds)] Deploying Fortune API $VERSION (currently $DEPLOYED_VERSION)."
        LAST_ATTEMPTED_VERSION="$VERSION"
        if bash "$DEPLOY_SCRIPT"; then
          echo "[$(date --iso-8601=seconds)] Fortune API $VERSION deployment completed."
          LAST_ATTEMPTED_VERSION=""
        else
          echo "[$(date --iso-8601=seconds)] Fortune API $VERSION deployment failed; retrying in 30 seconds." >&2
          LAST_ATTEMPTED_VERSION=""
          sleep 30
        fi
      fi
    elif [[ "$VERSION" != "$LAST_ATTEMPTED_VERSION" ]]; then
      echo "[$(date --iso-8601=seconds)] Unsupported version '$VERSION'; expected v1, v2, v3, or v4." >&2
      LAST_ATTEMPTED_VERSION="$VERSION"
    fi
  else
    echo "[$(date --iso-8601=seconds)] Cannot read version file: $VERSION_FILE" >&2
  fi

  sleep 3
done
