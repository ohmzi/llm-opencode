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
require_profile_vars LMS LMSTUDIO_MODELS_URL LMSTUDIO_BACKENDS_DIR LMSTUDIO_EXTENSION_CPYTHON_NAME CHAT_ID CHAT_GET_REF CHAT_MODEL_KEY CHAT_MODEL_PATH CHAT_CONTEXT CHAT_TTL CHAT_GPU CHAT_PARALLEL FAST_ID FAST_GET_REF FAST_MODEL_KEY FAST_MODEL_PATH FAST_CONTEXT FAST_TTL FAST_GPU FAST_PARALLEL EMBED_ID EMBED_TTL

REPAIR="$SCRIPT_DIR/repair-lmstudio-mlx-runtime.sh"

loaded_context_for() {
  local model_id="$1"
  curl -s --max-time 5 "$LMSTUDIO_MODELS_URL" | MODEL_ID="$model_id" /usr/bin/python3 -c 'import json,os,sys
try:
 data=json.load(sys.stdin)
except Exception:
 print("")
 raise SystemExit
for row in data.get("data", []):
 if row.get("id") == os.environ["MODEL_ID"] and row.get("state") == "loaded":
  print(row.get("loaded_context_length") or "")
' 2>/dev/null || true
}

resolve_model_key() {
  local model_id="$1"
  local model_key="$2"
  local model_path="$3"
  local get_ref="$4"
  "$LMS" ls --json | MODEL_ID="$model_id" MODEL_KEY="$model_key" MODEL_PATH="$model_path" MODEL_GET_REF="$get_ref" /usr/bin/python3 -c 'import json,os,sys
try:
 data=json.load(sys.stdin)
except Exception:
 print("")
 raise SystemExit
needles={os.environ.get("MODEL_ID",""),os.environ.get("MODEL_KEY",""),os.environ.get("MODEL_PATH",""),os.environ.get("MODEL_GET_REF","")}
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

chat_model_key="$(resolve_model_key "$CHAT_ID" "$CHAT_MODEL_KEY" "$CHAT_MODEL_PATH" "$CHAT_GET_REF")"
if [[ -z "$chat_model_key" ]]; then
  "$LMS" get "$CHAT_GET_REF" --mlx --yes
  chat_model_key="$(resolve_model_key "$CHAT_ID" "$CHAT_MODEL_KEY" "$CHAT_MODEL_PATH" "$CHAT_GET_REF")"
fi
if [[ -z "$chat_model_key" ]]; then
  echo "Could not resolve installed chat model for $CHAT_GET_REF" >&2
  exit 1
fi

fast_model_key="$(resolve_model_key "$FAST_ID" "$FAST_MODEL_KEY" "$FAST_MODEL_PATH" "$FAST_GET_REF")"
if [[ -z "$fast_model_key" ]]; then
  "$LMS" get "$FAST_GET_REF" --mlx --yes
  fast_model_key="$(resolve_model_key "$FAST_ID" "$FAST_MODEL_KEY" "$FAST_MODEL_PATH" "$FAST_GET_REF")"
fi
if [[ -z "$fast_model_key" ]]; then
  echo "Could not resolve installed fast model for $FAST_GET_REF" >&2
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
    if [[ "$(loaded_context_for "$CHAT_ID")" != "$CHAT_CONTEXT" ]]; then
      echo "Failed to load $CHAT_ID at context $CHAT_CONTEXT" >&2
      exit 1
    fi
  fi
fi

if [[ "$(loaded_context_for "$FAST_ID")" != "$FAST_CONTEXT" ]]; then
  "$LMS" load "$fast_model_key" \
    --identifier "$FAST_ID" \
    --context-length "$FAST_CONTEXT" \
    --gpu "$FAST_GPU" \
    --parallel "$FAST_PARALLEL" \
    --ttl "$FAST_TTL" \
    --yes || {
      sleep 2
      if [[ "$(loaded_context_for "$FAST_ID")" != "$FAST_CONTEXT" ]]; then
        echo "Failed to load $FAST_ID at context $FAST_CONTEXT" >&2
        exit 1
      fi
    }
fi

if [[ -z "$(loaded_context_for "$EMBED_ID")" ]]; then
  "$LMS" load "$EMBED_ID" \
    --identifier "$EMBED_ID" \
    --ttl "$EMBED_TTL" \
    --yes
fi
