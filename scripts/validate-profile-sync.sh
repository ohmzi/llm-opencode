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
require_profile_vars OPENCODE_PROVIDER LMSTUDIO_BASE_URL CHAT_ID CHAT_CONTEXT CHAT_OUTPUT CHAT_MODEL_DISPLAY FAST_ID FAST_CONTEXT FAST_OUTPUT FAST_MODEL_DISPLAY OPENCODE_DEFAULT_AGENT OPENCODE_MODEL OPENCODE_SMALL_MODEL OPENCODE_CODER_MODEL OPENCODE_QWEN_INSTRUCTIONS OPENCODE_WORKFLOW_INSTRUCTIONS OPENCODE_DESKTOP_STATE OPENCODE_INDEX_ROOTS OPENCODE_INDEX_AUTODISCOVER OPENCODE_INDEX_BACKGROUND OPENCODE_INDEX_BACKGROUND_SECONDS OPENCODE_INDEX_AUTO_SYNC_SECONDS OPENCODE_INDEX_DB OPENCODE_DEV_ROOTS LMSTUDIO_EMBEDDING_URL EMBED_ID OPENCODE_COMPACTION_RESERVED LOCAL_DEV_COMMAND_TIMEOUT LOCAL_DEV_MAX_TIMEOUT LOCAL_DEV_MAX_OUTPUT_CHARS LOCAL_DEV_MAX_TREE_ENTRIES

if [[ -n "${OPENCODE_BACKUP_CONFIG:-}" ]]; then
  CONFIG="$OPENCODE_BACKUP_CONFIG"
  if [[ "$CONFIG" != /* ]]; then
    CONFIG="$ROOT/$CONFIG"
    if [[ ! -f "$CONFIG" && -n "${OPENCODE_CONFIG:-}" ]]; then
      CONFIG="$OPENCODE_CONFIG"
    fi
  fi
elif [[ -f "$ROOT/config/opencode.json" ]]; then
  CONFIG="$ROOT/config/opencode.json"
else
  CONFIG="${OPENCODE_CONFIG:-$SCRIPT_DIR/opencode.json}"
fi

jq -e \
  --arg provider "$OPENCODE_PROVIDER" \
  --arg base_url "$LMSTUDIO_BASE_URL" \
  --arg default_agent "$OPENCODE_DEFAULT_AGENT" \
  --arg model "$OPENCODE_MODEL" \
  --arg small_model "$OPENCODE_SMALL_MODEL" \
  --arg coder_model "$OPENCODE_CODER_MODEL" \
  --arg chat_id "$CHAT_ID" \
  --arg display "$CHAT_MODEL_DISPLAY" \
  --arg fast_id "$FAST_ID" \
  --arg fast_display "$FAST_MODEL_DISPLAY" \
  --arg qwen_instructions "$OPENCODE_QWEN_INSTRUCTIONS" \
  --arg workflow_instructions "$OPENCODE_WORKFLOW_INSTRUCTIONS" \
  --argjson context "$CHAT_CONTEXT" \
  --argjson output "$CHAT_OUTPUT" \
  --argjson fast_context "$FAST_CONTEXT" \
  --argjson fast_output "$FAST_OUTPUT" \
  --argjson reserved "$OPENCODE_COMPACTION_RESERVED" \
  '
  (.enabled_providers == [$provider]) and
  (.default_agent == $default_agent) and
  (.instructions == [$qwen_instructions, $workflow_instructions]) and
  (.provider[$provider].options.baseURL == $base_url) and
  (.provider[$provider].whitelist == [$chat_id, $fast_id]) and
  (.provider[$provider].models[$chat_id].name == $display) and
  (.provider[$provider].models[$chat_id].tool_call == true) and
  (.provider[$provider].models[$chat_id].reasoning == false) and
  (.provider[$provider].models[$chat_id].attachment == true) and
  (.provider[$provider].models[$chat_id].limit.context == $context) and
  (.provider[$provider].models[$chat_id].limit.output == $output) and
  (.provider[$provider].models[$fast_id].name == $fast_display) and
  (.provider[$provider].models[$fast_id].tool_call == true) and
  (.provider[$provider].models[$fast_id].limit.context == $fast_context) and
  (.provider[$provider].models[$fast_id].limit.output == $fast_output) and
  (.model == $model) and
  (.small_model == $small_model) and
  (.compaction.reserved == $reserved) and
  (.agent.fast.model == $small_model) and
  (.agent.explain.model == $small_model) and
  (.agent.build.model == $coder_model) and
  (.agent.indexer.model == $coder_model) and
  (.agent.plan.model == $coder_model) and
  (.agent.build.steps == 18) and
  (.agent.plan.steps == 10) and
  (.agent."codebase-researcher".steps == 10) and
  (.agent.debugger.steps == 12) and
  (.agent.build.permission."local_code_index_*" == "deny") and
  (.agent.build.permission."local_dev_tools_*" == "deny") and
  (.agent.build.permission."context7_*" == "deny") and
  (.agent.build.permission."gh_grep_*" == "deny") and
  (.command.explain.agent == "explain") and
  (.command.research.agent == "codebase-researcher") and
  (.command.implement.agent == "build") and
  (.command.index.agent == "indexer")
  ' "$CONFIG" >/dev/null

jq -e \
  --arg roots "$OPENCODE_INDEX_ROOTS" \
  --arg autodiscover "$OPENCODE_INDEX_AUTODISCOVER" \
  --arg desktop "$OPENCODE_DESKTOP_STATE" \
  --arg background "$OPENCODE_INDEX_BACKGROUND" \
  --arg seconds "$OPENCODE_INDEX_BACKGROUND_SECONDS" \
  --arg auto_seconds "$OPENCODE_INDEX_AUTO_SYNC_SECONDS" \
  --arg db "$OPENCODE_INDEX_DB" \
  --arg embed_url "$LMSTUDIO_EMBEDDING_URL" \
  --arg embed_model "$EMBED_ID" \
  --arg dev_roots "$OPENCODE_DEV_ROOTS" \
  --arg dev_timeout "$LOCAL_DEV_COMMAND_TIMEOUT" \
  --arg dev_max_timeout "$LOCAL_DEV_MAX_TIMEOUT" \
  --arg dev_max_output "$LOCAL_DEV_MAX_OUTPUT_CHARS" \
  --arg dev_max_tree "$LOCAL_DEV_MAX_TREE_ENTRIES" \
  '
  (.mcp.local_code_index.environment.OPENCODE_INDEX_ROOTS == $roots) and
  (.mcp.local_code_index.environment.OPENCODE_INDEX_AUTODISCOVER == $autodiscover) and
  (.mcp.local_code_index.environment.OPENCODE_DESKTOP_STATE == $desktop) and
  (.mcp.local_code_index.environment.OPENCODE_INDEX_BACKGROUND == $background) and
  (.mcp.local_code_index.environment.OPENCODE_INDEX_BACKGROUND_SECONDS == $seconds) and
  (.mcp.local_code_index.environment.OPENCODE_INDEX_AUTO_SYNC_SECONDS == $auto_seconds) and
  (.mcp.local_code_index.environment.OPENCODE_INDEX_DB == $db) and
  (.mcp.local_code_index.environment.LMSTUDIO_EMBEDDING_URL == $embed_url) and
  (.mcp.local_code_index.environment.LMSTUDIO_EMBEDDING_MODEL == $embed_model) and
  (.mcp.local_dev_tools.environment.OPENCODE_DEV_ROOTS == $dev_roots) and
  (.mcp.local_dev_tools.environment.OPENCODE_DESKTOP_STATE == $desktop) and
  (.mcp.local_dev_tools.environment.LOCAL_DEV_COMMAND_TIMEOUT == $dev_timeout) and
  (.mcp.local_dev_tools.environment.LOCAL_DEV_MAX_TIMEOUT == $dev_max_timeout) and
  (.mcp.local_dev_tools.environment.LOCAL_DEV_MAX_OUTPUT_CHARS == $dev_max_output) and
  (.mcp.local_dev_tools.environment.LOCAL_DEV_MAX_TREE_ENTRIES == $dev_max_tree) and
  (.mcp.context7.type == "remote") and
  (.mcp.context7.url == "https://mcp.context7.com/mcp") and
  (.mcp.gh_grep.type == "remote") and
  (.mcp.gh_grep.url == "https://mcp.grep.app")
  ' "$CONFIG" >/dev/null

jq -e \
  '
  (.mcp | keys == ["context7","gh_grep","local_code_index","local_dev_tools"]) and
  (.agent | keys == ["build","code-reviewer","codebase-researcher","debugger","doc-researcher","explain","fast","indexer","plan","security-auditor","test-runner"]) and
  (.command | keys == ["debug","docs","explain","implement","index","research","review","security","test"]) and
  (.lsp | keys == ["eslint","typescript"]) and
  (.lsp.typescript.command == ["npx","--yes","typescript-language-server","--stdio"]) and
  (.lsp.eslint.command == ["npx","--yes","vscode-eslint-language-server","--stdio"])
  ' "$CONFIG" >/dev/null

echo "Profile/config sync OK: $LLM_OPENCODE_PROFILE"
