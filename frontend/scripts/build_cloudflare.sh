#!/usr/bin/env bash
set -euo pipefail
export CI=true

FLUTTER_VERSION="3.44.6"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="${REPO_ROOT}/frontend/build/cloudflare-pages"
FLUTTER_ROOT="${HOME}/.cache/ginata/flutter-${FLUTTER_VERSION}"

if ! command -v flutter >/dev/null 2>&1; then
  mkdir -p "$(dirname "$FLUTTER_ROOT")"
  if [ ! -x "${FLUTTER_ROOT}/bin/flutter" ]; then
    git clone --depth 1 --branch "$FLUTTER_VERSION" \
      https://github.com/flutter/flutter.git "$FLUTTER_ROOT"
  fi
  export PATH="${FLUTTER_ROOT}/bin:${PATH}"
fi

mkdir -p "$OUTPUT_DIR"
cp -R "${REPO_ROOT}/ginata property website/assets" "$OUTPUT_DIR/"
cp "${REPO_ROOT}/ginata property website/index.html" \
  "${REPO_ROOT}/ginata property website/download.html" \
  "${REPO_ROOT}/ginata property website/script.js" \
  "${REPO_ROOT}/ginata property website/styles.css" "$OUTPUT_DIR/"

cd "${REPO_ROOT}/frontend"
flutter pub get
flutter build web \
  --release \
  --base-href /app/ \
  --dart-define=API_URL=https://ginata-backend.onrender.com/api/v1 \
  --output "${OUTPUT_DIR}/app"
