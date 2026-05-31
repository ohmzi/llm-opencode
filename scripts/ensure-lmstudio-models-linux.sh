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
require_profile_vars LMS LMSTUDIO_MODELS_URL CHAT_ID CHAT_GET_REF CHAT_MODEL_KEY CHAT_MODEL_PATH CHAT_MODEL_FILENAME CHAT_CONTEXT CHAT_CONTEXT_FALLBACK_1 CHAT_CONTEXT_FALLBACK_2 CHAT_TTL CHAT_GPU CHAT_PARALLEL EMBED_ID EMBED_TTL

resolve_lms() {
  if [[ "$LMS" == */* && -x "$LMS" ]]; then
    print -- "$LMS"
    return 0
  fi
  command -v "$LMS" 2>/dev/null || command -v lms 2>/dev/null
}

LMS_BIN="$(resolve_lms || true)"
if [[ -z "$LMS_BIN" ]]; then
  echo "LM Studio lms CLI not found. Run LM Studio once, then make sure lms is in PATH." >&2
  exit 1
fi

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
  "$LMS_BIN" ls --json | CHAT_ID="$CHAT_ID" CHAT_MODEL_KEY="$CHAT_MODEL_KEY" CHAT_MODEL_PATH="$CHAT_MODEL_PATH" CHAT_MODEL_FILENAME="$CHAT_MODEL_FILENAME" CHAT_GET_REF="$CHAT_GET_REF" /usr/bin/python3 -c 'import json,os,sys
try:
 data=json.load(sys.stdin)
except Exception:
 print("")
 raise SystemExit
needles={os.environ.get("CHAT_ID",""),os.environ.get("CHAT_MODEL_KEY",""),os.environ.get("CHAT_MODEL_PATH",""),os.environ.get("CHAT_GET_REF","")}
filename=os.environ.get("CHAT_MODEL_FILENAME","")
for row in data:
 values={str(row.get("modelKey","")),str(row.get("path","")),str(row.get("indexedModelIdentifier",""))}
 if values & needles or any(filename and filename in value for value in values):
  print(row.get("modelKey") or row.get("path") or "")
  raise SystemExit
' 2>/dev/null || true
}

if ! "$LMS_BIN" status 2>/dev/null | grep -q 'Server:  ON'; then
  "$LMS_BIN" server start >/dev/null
fi

chat_model_key="$(resolve_chat_model_key)"
if [[ -z "$chat_model_key" ]]; then
  "$LMS_BIN" get "$CHAT_GET_REF" --gguf --yes
  chat_model_key="$(resolve_chat_model_key)"
fi
if [[ -z "$chat_model_key" ]]; then
  echo "Could not resolve installed chat model for $CHAT_GET_REF" >&2
  echo "In LM Studio, download $CHAT_MODEL_FILENAME from $CHAT_GET_REF, then re-run this script." >&2
  exit 1
fi

for _ in {1..30}; do
  if curl -s --max-time 2 "$LMSTUDIO_MODELS_URL" >/dev/null; then
    break
  fi
  sleep 1
done

if [[ "$(loaded_context)" != "$CHAT_CONTEXT" ]]; then
  "$LMS_BIN" unload --all >/dev/null 2>&1 || true
  for context in "$CHAT_CONTEXT" "$CHAT_CONTEXT_FALLBACK_1" "$CHAT_CONTEXT_FALLBACK_2"; do
    if "$LMS_BIN" load "$chat_model_key" \
      --identifier "$CHAT_ID" \
      --context-length "$context" \
      --gpu "$CHAT_GPU" \
      --parallel "$CHAT_PARALLEL" \
      --ttl "$CHAT_TTL" \
      --yes; then
      if [[ "$(loaded_context)" == "$context" ]]; then
        if [[ "$context" != "$CHAT_CONTEXT" ]]; then
          echo "Loaded $CHAT_ID at fallback context $context. Update CHAT_CONTEXT and the OpenCode config if this is the stable target." >&2
        fi
        break
      fi
    fi
    "$LMS_BIN" unload --all >/dev/null 2>&1 || true
  done
fi

if [[ -z "$(loaded_context)" ]]; then
  echo "Failed to load $CHAT_ID at configured or fallback contexts." >&2
  exit 1
fi

"$LMS_BIN" load "$EMBED_ID" \
  --identifier "$EMBED_ID" \
  --ttl "$EMBED_TTL" \
  --yes || true
