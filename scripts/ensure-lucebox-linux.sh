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

require_profile_vars LUCEBOX_HOME LUCEBOX_SERVER_BIN LUCEBOX_TARGET LUCEBOX_DRAFT LUCEBOX_TARGET_REPO LUCEBOX_TARGET_FILE LUCEBOX_DRAFT_REPO LUCEBOX_DRAFT_FILE

resolve_hf() {
  local found
  found="$(command -v hf 2>/dev/null || true)"
  [[ -n "$found" ]] && print -- "$found" && return 0
  found="$(command -v huggingface-cli 2>/dev/null || true)"
  [[ -n "$found" ]] && print -- "$found" && return 0
  [[ -x "$HOME/.local/bin/hf" ]] && print -- "$HOME/.local/bin/hf" && return 0
  [[ -x "$HOME/.local/share/pipx/venvs/huggingface-hub/bin/hf" ]] && print -- "$HOME/.local/share/pipx/venvs/huggingface-hub/bin/hf" && return 0
  return 1
}

download_model_file() {
  local repo="$1"
  local file="$2"
  local dest="$3"
  local hf_bin

  mkdir -p "$dest"
  hf_bin="$(resolve_hf || true)"
  if [[ -z "$hf_bin" ]]; then
    echo "Hugging Face CLI not found. Install it with: python3 -m pip install --user 'huggingface_hub[cli]'" >&2
    exit 1
  fi

  "$hf_bin" download "$repo" "$file" --local-dir "$dest"
}

if [[ ! -d "$LUCEBOX_HOME/.git" ]]; then
  echo "Lucebox repo not found at $LUCEBOX_HOME" >&2
  exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake not found. Install Ubuntu build deps first: sudo apt install -y build-essential cmake git-lfs" >&2
  exit 1
fi

git -C "$LUCEBOX_HOME" submodule update --init --recursive

if [[ ! -x "$LUCEBOX_SERVER_BIN" ]]; then
  cmake -B "$LUCEBOX_HOME/server/build" -S "$LUCEBOX_HOME/server" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES=86 \
    -DDFLASH27B_ENABLE_BSA=ON
  cmake --build "$LUCEBOX_HOME/server/build" --target dflash_server -j"$(nproc)"
fi

if [[ ! -f "$LUCEBOX_TARGET" ]]; then
  download_model_file "$LUCEBOX_TARGET_REPO" "$LUCEBOX_TARGET_FILE" "$LUCEBOX_HOME/server/models"
fi

if [[ ! -f "$LUCEBOX_DRAFT" ]]; then
  download_model_file "$LUCEBOX_DRAFT_REPO" "$LUCEBOX_DRAFT_FILE" "$LUCEBOX_HOME/server/models/draft"
fi

echo "Lucebox ready:"
echo "  server: $LUCEBOX_SERVER_BIN"
echo "  target: $LUCEBOX_TARGET"
echo "  draft:  $LUCEBOX_DRAFT"
