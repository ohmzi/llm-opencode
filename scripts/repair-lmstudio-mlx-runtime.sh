#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT="${SCRIPT_DIR:h}"
if [[ -f "$ROOT/scripts/lib/profile.sh" ]]; then
  source "$ROOT/scripts/lib/profile.sh"
elif [[ -f "$SCRIPT_DIR/lib/profile.sh" ]]; then
  source "$SCRIPT_DIR/lib/profile.sh"
else
  echo "Could not find scripts/lib/profile.sh" >&2
  exit 1
fi
require_profile_vars LMS LMSTUDIO_BACKENDS_DIR LMSTUDIO_BACKENDS_CACHE_DIR MLX_RUNTIME_NAX LMSTUDIO_EXTENSION_CPYTHON_NAME LMSTUDIO_EXTENSION_CPYTHON_URL LMSTUDIO_EXTENSION_CPYTHON_SHA256 LMSTUDIO_EXTENSION_MLX_STANDARD_NAME LMSTUDIO_EXTENSION_MLX_STANDARD_URL LMSTUDIO_EXTENSION_MLX_STANDARD_SHA256 LMSTUDIO_EXTENSION_APP_MLX_MAC14_NAME LMSTUDIO_EXTENSION_APP_MLX_MAC14_URL LMSTUDIO_EXTENSION_APP_MLX_MAC14_SHA256 LMSTUDIO_EXTENSION_MLX_NAX_NAME LMSTUDIO_EXTENSION_MLX_NAX_URL LMSTUDIO_EXTENSION_MLX_NAX_SHA256 LMSTUDIO_EXTENSION_APP_MLX_MAC26_NAME LMSTUDIO_EXTENSION_APP_MLX_MAC26_URL LMSTUDIO_EXTENSION_APP_MLX_MAC26_SHA256

BACKENDS="$LMSTUDIO_BACKENDS_DIR"
VENDOR="$BACKENDS/vendor/_amphibian"
CACHE="$LMSTUDIO_BACKENDS_CACHE_DIR"

mkdir -p "$VENDOR" "$CACHE"

fetch() {
  local name="$1"
  local url="$2"
  local sha="$3"
  local archive="$CACHE/$name.tar.gz"

  if [[ ! -f "$archive" ]] || [[ "$(shasum -a 256 "$archive" | awk '{print $1}')" != "$sha" ]]; then
    echo "Downloading $name"
    curl -fL "$url" -o "$archive"
  fi

  local actual
  actual="$(shasum -a 256 "$archive" | awk '{print $1}')"
  if [[ "$actual" != "$sha" ]]; then
    echo "Checksum failed for $name: expected $sha, got $actual" >&2
    exit 1
  fi
}

extract_pack() {
  local name="$1"
  local url="$2"
  local sha="$3"
  local dest="$4"
  local marker="$5"

  if [[ -e "$dest/$marker" && "${FORCE_REPAIR:-0}" != "1" ]]; then
    return
  fi

  fetch "$name" "$url" "$sha"

  local archive="$CACHE/$name.tar.gz"
  local unpack="$CACHE/$name.unpack"
  rm -rf "$unpack" "$dest.tmp"
  mkdir -p "$unpack"
  tar -xzf "$archive" -C "$unpack"

  if [[ -e "$unpack/$marker" ]]; then
    mv "$unpack" "$dest.tmp"
  elif [[ -d "$unpack/$(basename "$dest")" ]]; then
    mv "$unpack/$(basename "$dest")" "$dest.tmp"
  else
    echo "Could not find marker $marker in $name archive" >&2
    find "$unpack" -maxdepth 3 -type f | sed -n '1,40p' >&2
    exit 1
  fi

  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  mv "$dest.tmp" "$dest"
}

extract_pack \
  "$LMSTUDIO_EXTENSION_CPYTHON_NAME" \
  "$LMSTUDIO_EXTENSION_CPYTHON_URL" \
  "$LMSTUDIO_EXTENSION_CPYTHON_SHA256" \
  "$VENDOR/${LMSTUDIO_EXTENSION_CPYTHON_NAME#vendor-_amphibian-}" \
  "lib/libpython3.11.dylib"

extract_pack \
  "$LMSTUDIO_EXTENSION_MLX_STANDARD_NAME" \
  "$LMSTUDIO_EXTENSION_MLX_STANDARD_URL" \
  "$LMSTUDIO_EXTENSION_MLX_STANDARD_SHA256" \
  "$BACKENDS/${LMSTUDIO_EXTENSION_MLX_STANDARD_NAME#backend-}" \
  "llm_engine_mlx_amphibian.node"

extract_pack \
  "$LMSTUDIO_EXTENSION_APP_MLX_MAC14_NAME" \
  "$LMSTUDIO_EXTENSION_APP_MLX_MAC14_URL" \
  "$LMSTUDIO_EXTENSION_APP_MLX_MAC14_SHA256" \
  "$VENDOR/${LMSTUDIO_EXTENSION_APP_MLX_MAC14_NAME#vendor-_amphibian-}" \
  "bin/python"

extract_pack \
  "$LMSTUDIO_EXTENSION_MLX_NAX_NAME" \
  "$LMSTUDIO_EXTENSION_MLX_NAX_URL" \
  "$LMSTUDIO_EXTENSION_MLX_NAX_SHA256" \
  "$BACKENDS/${LMSTUDIO_EXTENSION_MLX_NAX_NAME#backend-}" \
  "llm_engine_mlx_amphibian.node"

extract_pack \
  "$LMSTUDIO_EXTENSION_APP_MLX_MAC26_NAME" \
  "$LMSTUDIO_EXTENSION_APP_MLX_MAC26_URL" \
  "$LMSTUDIO_EXTENSION_APP_MLX_MAC26_SHA256" \
  "$VENDOR/${LMSTUDIO_EXTENSION_APP_MLX_MAC26_NAME#vendor-_amphibian-}" \
  "bin/python"

PY="$VENDOR/${LMSTUDIO_EXTENSION_CPYTHON_NAME#vendor-_amphibian-}/bin/python3.11"
if [[ ! -x "$PY" ]]; then
  echo "Repaired CPython layer is missing $PY" >&2
  exit 1
fi

for dir in \
  "$VENDOR/${LMSTUDIO_EXTENSION_CPYTHON_NAME#vendor-_amphibian-}" \
  "$VENDOR/${LMSTUDIO_EXTENSION_APP_MLX_MAC14_NAME#vendor-_amphibian-}" \
  "$VENDOR/${LMSTUDIO_EXTENSION_APP_MLX_MAC26_NAME#vendor-_amphibian-}"; do
  if [[ -f "$dir/postinstall.py" ]]; then
    "$PY" "$dir/postinstall.py"
  fi
done

if [[ -x "$LMS" ]]; then
  "$LMS" runtime select "$MLX_RUNTIME_NAX" >/dev/null 2>&1 || true
fi

echo "LM Studio MLX runtime repair complete."
