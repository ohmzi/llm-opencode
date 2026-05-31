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
require_profile_vars LMS LMSTUDIO_MODELS_URL LMSTUDIO_BACKENDS_DIR LMSTUDIO_EXTENSION_CPYTHON_NAME CHAT_ID CHAT_GET_REF CHAT_MODEL_KEY CHAT_MODEL_PATH CHAT_CONTEXT CHAT_TTL CHAT_GPU CHAT_PARALLEL EMBED_ID EMBED_TTL

REPAIR="$SCRIPT_DIR/repair-lmstudio-mlx-runtime.sh"

loaded_context() {
  curl -s --max-time 5 "$LMSTUDIO_MODELS_URL" | CHAT_ID="$CHAT_ID" /usr/bin/python3 -c 'import json,os,sys
try:
 data=json.load(sys.stdin)
except Exception:
 print("")
 raise SystemExit
for row in data.get("data", []):
 if row.get("id") == os.environ["CHAT_ID"] and row.get("state") == "loaded":
  print(row.get("loaded_context_length") or "")
' 2>/dev/null || true
}

resolve_chat_model_key() {
  "$LMS" ls --json | CHAT_ID="$CHAT_ID" CHAT_MODEL_KEY="$CHAT_MODEL_KEY" CHAT_MODEL_PATH="$CHAT_MODEL_PATH" CHAT_GET_REF="$CHAT_GET_REF" /usr/bin/python3 -c 'import json,os,sys
try:
 data=json.load(sys.stdin)
except Exception:
 print("")
 raise SystemExit
needles={os.environ.get("CHAT_ID",""),os.environ.get("CHAT_MODEL_KEY",""),os.environ.get("CHAT_MODEL_PATH",""),os.environ.get("CHAT_GET_REF","")}
for row in data:
 values={str(row.get("modelKey","")),str(row.get("path","")),str(row.get("indexedModelIdentifier",""))}
 if values & needles:
  print(row.get("modelKey") or row.get("path") or "")
  raise SystemExit
' 2>/dev/null || true
}

if [[ ! -x "$LMS" ]]; then
  echo "LM Studio CLI not found at $LMS" >&2
  exit 1
fi

if [[ ! -f "$LMSTUDIO_BACKENDS_DIR/vendor/_amphibian/${LMSTUDIO_EXTENSION_CPYTHON_NAME#vendor-_amphibian-}/lib/libpython3.11.dylib" && -x "$REPAIR" ]]; then
  "$REPAIR"
fi

if ! "$LMS" status 2>/dev/null | grep -q 'Server:  ON'; then
  "$LMS" server start >/dev/null
fi

chat_model_key="$(resolve_chat_model_key)"
if [[ -z "$chat_model_key" ]]; then
  "$LMS" get "$CHAT_GET_REF" --mlx --yes
  chat_model_key="$(resolve_chat_model_key)"
fi
if [[ -z "$chat_model_key" ]]; then
  echo "Could not resolve installed chat model for $CHAT_GET_REF" >&2
  exit 1
fi

for _ in {1..30}; do
  if curl -s --max-time 2 "$LMSTUDIO_MODELS_URL" >/dev/null; then
    break
  fi
  sleep 1
done

model_json="$(curl -s --max-time 5 "$LMSTUDIO_MODELS_URL" || true)"
chat_context="$(printf '%s' "$model_json" | CHAT_ID="$CHAT_ID" /usr/bin/python3 -c 'import json,os,sys
try:
 data=json.load(sys.stdin)
except Exception:
 print("")
 raise SystemExit
for row in data.get("data", []):
 if row.get("id") == os.environ["CHAT_ID"] and row.get("state") == "loaded":
  print(row.get("loaded_context_length") or "")
' 2>/dev/null || true)"
embed_loaded="$(printf '%s' "$model_json" | EMBED_ID="$EMBED_ID" /usr/bin/python3 -c 'import json,os,sys
try:
 data=json.load(sys.stdin)
except Exception:
 print("")
 raise SystemExit
for row in data.get("data", []):
 if row.get("id") == os.environ["EMBED_ID"] and row.get("state") == "loaded":
  print("1")
' 2>/dev/null || true)"

if [[ "$chat_context" != "$CHAT_CONTEXT" ]]; then
  "$LMS" unload --all >/dev/null 2>&1 || true
  if ! "$LMS" load "$chat_model_key" \
    --identifier "$CHAT_ID" \
    --context-length "$CHAT_CONTEXT" \
    --gpu "$CHAT_GPU" \
    --parallel "$CHAT_PARALLEL" \
    --ttl "$CHAT_TTL" \
    --yes; then
    sleep 2
    if [[ "$(loaded_context)" != "$CHAT_CONTEXT" ]]; then
      echo "Failed to load $CHAT_ID at context $CHAT_CONTEXT" >&2
      exit 1
    fi
  fi
fi

"$LMS" load "$EMBED_ID" \
  --identifier "$EMBED_ID" \
  --ttl "$EMBED_TTL" \
  --yes || true
