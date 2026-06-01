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

require_profile_vars LUCEBOX_HOME LUCEBOX_SERVER_BIN LUCEBOX_TARGET LUCEBOX_DRAFT LUCEBOX_HOST LUCEBOX_PORT LUCEBOX_CONTEXT LUCEBOX_OUTPUT LUCEBOX_MODEL_ID LUCEBOX_DDTREE_BUDGET LUCEBOX_FA_WINDOW LUCEBOX_CACHE_TYPE_K LUCEBOX_CACHE_TYPE_V

if [[ ! -x "$LUCEBOX_SERVER_BIN" ]]; then
  echo "Missing Lucebox server binary: $LUCEBOX_SERVER_BIN" >&2
  echo "Run ensure-lucebox-linux.sh first." >&2
  exit 1
fi

if [[ ! -f "$LUCEBOX_TARGET" ]]; then
  echo "Missing Lucebox target model: $LUCEBOX_TARGET" >&2
  exit 1
fi

if [[ ! -f "$LUCEBOX_DRAFT" ]]; then
  echo "Missing Lucebox draft model: $LUCEBOX_DRAFT" >&2
  exit 1
fi

export DFLASH27B_KV_K="$LUCEBOX_CACHE_TYPE_K"
export DFLASH27B_KV_V="$LUCEBOX_CACHE_TYPE_V"

typeset -a extra_args
extra_args=()
if [[ -n "${LUCEBOX_EXTRA_ARGS:-}" ]]; then
  extra_args=(${=LUCEBOX_EXTRA_ARGS})
fi

cd "$LUCEBOX_HOME"
exec "$LUCEBOX_SERVER_BIN" "$LUCEBOX_TARGET" \
  --draft "$LUCEBOX_DRAFT" \
  --host "$LUCEBOX_HOST" \
  --port "$LUCEBOX_PORT" \
  --max-ctx "$LUCEBOX_CONTEXT" \
  --max-tokens "$LUCEBOX_OUTPUT" \
  --model-name "$LUCEBOX_MODEL_ID" \
  --ddtree \
  --ddtree-budget "$LUCEBOX_DDTREE_BUDGET" \
  --fa-window "$LUCEBOX_FA_WINDOW" \
  --cache-type-k "$LUCEBOX_CACHE_TYPE_K" \
  --cache-type-v "$LUCEBOX_CACHE_TYPE_V" \
  "${extra_args[@]}"
