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
require_profile_vars LMSTUDIO_BASE_URL CHAT_ID CHAT_CONTEXT CHAT_OUTPUT CHAT_MODEL_DISPLAY OPENCODE_MODEL OPENCODE_DESKTOP_STATE OPENCODE_INDEX_ROOTS OPENCODE_INDEX_AUTODISCOVER OPENCODE_INDEX_BACKGROUND OPENCODE_INDEX_BACKGROUND_SECONDS OPENCODE_INDEX_DB OPENCODE_DEV_ROOTS LMSTUDIO_EMBEDDING_URL EMBED_ID SOURCEKIT_LSP DEVELOPER_DIR TOOLCHAINS

if [[ -f "$ROOT/config/opencode.json" ]]; then
  CONFIG="$ROOT/config/opencode.json"
else
  CONFIG="${OPENCODE_CONFIG:-$SCRIPT_DIR/opencode.json}"
fi

jq -e \
  --arg provider "$OPENCODE_PROVIDER" \
  --arg base_url "$LMSTUDIO_BASE_URL" \
  --arg model "$OPENCODE_MODEL" \
  --arg chat_id "$CHAT_ID" \
  --arg display "$CHAT_MODEL_DISPLAY" \
  --argjson context "$CHAT_CONTEXT" \
  --argjson output "$CHAT_OUTPUT" \
  '
  (.enabled_providers == [$provider]) and
  (.provider[$provider].options.baseURL == $base_url) and
  (.provider[$provider].whitelist == [$chat_id]) and
  (.provider[$provider].models[$chat_id].name == $display) and
  (.provider[$provider].models[$chat_id].tool_call == true) and
  (.provider[$provider].models[$chat_id].limit.context == $context) and
  (.provider[$provider].models[$chat_id].limit.output == $output) and
  (.model == $model) and
  (.small_model == $model) and
  (.agent | to_entries | all(.value.model == $model))
  ' "$CONFIG" >/dev/null

jq -e \
  --arg roots "$OPENCODE_INDEX_ROOTS" \
  --arg autodiscover "$OPENCODE_INDEX_AUTODISCOVER" \
  --arg desktop "$OPENCODE_DESKTOP_STATE" \
  --arg background "$OPENCODE_INDEX_BACKGROUND" \
  --arg seconds "$OPENCODE_INDEX_BACKGROUND_SECONDS" \
  --arg db "$OPENCODE_INDEX_DB" \
  --arg embed_url "$LMSTUDIO_EMBEDDING_URL" \
  --arg embed_model "$EMBED_ID" \
  --arg dev_roots "$OPENCODE_DEV_ROOTS" \
  '
  (.mcp.local_code_index.environment.OPENCODE_INDEX_ROOTS == $roots) and
  (.mcp.local_code_index.environment.OPENCODE_INDEX_AUTODISCOVER == $autodiscover) and
  (.mcp.local_code_index.environment.OPENCODE_DESKTOP_STATE == $desktop) and
  (.mcp.local_code_index.environment.OPENCODE_INDEX_BACKGROUND == $background) and
  (.mcp.local_code_index.environment.OPENCODE_INDEX_BACKGROUND_SECONDS == $seconds) and
  (.mcp.local_code_index.environment.OPENCODE_INDEX_DB == $db) and
  (.mcp.local_code_index.environment.LMSTUDIO_EMBEDDING_URL == $embed_url) and
  (.mcp.local_code_index.environment.LMSTUDIO_EMBEDDING_MODEL == $embed_model) and
  (.mcp.local_dev_tools.environment.OPENCODE_DEV_ROOTS == $dev_roots) and
  (.mcp.local_dev_tools.environment.OPENCODE_DESKTOP_STATE == $desktop)
  ' "$CONFIG" >/dev/null

jq -e \
  --arg sourcekit "$SOURCEKIT_LSP" \
  --arg developer "$DEVELOPER_DIR" \
  --arg toolchains "$TOOLCHAINS" \
  '
  (.mcp | keys == ["context7","gh_grep","local_code_index","local_dev_tools"]) and
  (.agent | keys == ["build","debug","plan","review"]) and
  (.command | keys == ["debug","docs","index","reindex","review","search-index"]) and
  (.lsp["sourcekit-lsp"].command == [$sourcekit]) and
  (.lsp["sourcekit-lsp"].env.DEVELOPER_DIR == $developer) and
  (.lsp["sourcekit-lsp"].env.TOOLCHAINS == $toolchains)
  ' "$CONFIG" >/dev/null

echo "Profile/config sync OK: $LLM_OPENCODE_PROFILE"
