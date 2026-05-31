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
require_profile_vars LMS CHAT_ID CHAT_GET_REF CHAT_MODEL_KEY CHAT_MODEL_PATH EMBED_ID EMBED_MODEL_PATH
if [[ -n "${FAST_ID:-}" ]]; then
  require_profile_vars FAST_GET_REF FAST_MODEL_KEY FAST_MODEL_PATH
fi

resolve_lms() {
  if [[ "$LMS" == */* && -x "$LMS" ]]; then
    print -- "$LMS"
    return 0
  fi
  command -v "$LMS" 2>/dev/null || command -v lms 2>/dev/null
}

LMS_BIN="$(resolve_lms || true)"
if [[ -z "$LMS_BIN" ]]; then
  echo "LM Studio lms CLI not found at $LMS"
  exit 1
fi

echo "Installed LM Studio models:"
"$LMS_BIN" ls --json | jq -r '.[] | [.modelKey, .path, .format, (.quantization.name // "")] | @tsv'

echo
echo "Loaded LM Studio models:"
"$LMS_BIN" ps || true

missing=0
"$LMS_BIN" ls --json | jq -e --arg id "$CHAT_ID" --arg key "$CHAT_MODEL_KEY" --arg path "$CHAT_MODEL_PATH" --arg ref "$CHAT_GET_REF" '.[] | select(.modelKey == $id or .modelKey == $key or .path == $path or .indexedModelIdentifier == $ref or ((.path // "") | contains($path)))' >/dev/null || {
  echo "Missing expected chat model: $CHAT_GET_REF ($CHAT_MODEL_PATH), loaded as $CHAT_ID"
  missing=1
}
if [[ -n "${FAST_ID:-}" ]]; then
  "$LMS_BIN" ls --json | jq -e --arg id "$FAST_ID" --arg key "$FAST_MODEL_KEY" --arg path "$FAST_MODEL_PATH" --arg ref "$FAST_GET_REF" '.[] | select(.modelKey == $id or .modelKey == $key or .path == $path or .indexedModelIdentifier == $ref or ((.path // "") | contains($path)))' >/dev/null || {
    echo "Missing expected fast model: $FAST_GET_REF ($FAST_MODEL_PATH), loaded as $FAST_ID"
    missing=1
  }
fi
"$LMS_BIN" ls --json | jq -e --arg id "$EMBED_ID" --arg path "$EMBED_MODEL_PATH" '.[] | select(.modelKey == $id or .path == $path)' >/dev/null || {
  echo "Missing expected embedding model: $EMBED_ID ($EMBED_MODEL_PATH)"
  missing=1
}

exit "$missing"
