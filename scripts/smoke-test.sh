#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
source "$ROOT/scripts/lib/profile.sh"
require_profile_vars LMS PROFILE_NAME EXPECTED_ARCH MIN_MEM_BYTES MAX_MEM_BYTES LMSTUDIO_HOST LMSTUDIO_PORT LMSTUDIO_BASE_URL LMSTUDIO_MODELS_URL LMSTUDIO_EMBEDDING_URL CHAT_ID CHAT_CONTEXT EMBED_ID EMBED_DIMENSIONS OPENCODE_DESKTOP_STATE OPENCODE_INDEX_DB OPENCODE_DEV_ROOTS OPENCODE_INDEX_ROOTS OPENCODE_INDEX_AUTODISCOVER OPENCODE_ENABLE_EXA OPENCODE_EXPERIMENTAL_LSP_TOOL

ok() { print "ok - $1"; }
fail() { print "not ok - $1" >&2; exit 1; }

remote_mcp_call_ok() {
  local target="$1"
  local call_json="$2"
  local label="$3"
  local response=""
  local attempt

  for attempt in {1..3}; do
    response="$(printf '%s\n' \
      '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}' \
      '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
      "$call_json" \
      | PROXY_TARGET="$target" python3 "$ROOT/mcp/remote_mcp_proxy.py" 2>/dev/null | tail -n 1 || true)"

    if printf '%s\n' "$response" | jq -e '.result.isError != true and (.result.content | length > 0)' >/dev/null 2>&1; then
      ok "$label"
      return 0
    fi
    sleep 2
  done

  printf '%s\n' "$response" >&2
  fail "$label"
}

if [[ "${SMOKE_SKIP_HARDWARE:-0}" != "1" ]]; then
  [[ "$(uname -m)" == "$EXPECTED_ARCH" ]] || fail "Apple Silicon $EXPECTED_ARCH required"
  mem="$(sysctl -n hw.memsize)"
  [[ "$mem" -ge "$MIN_MEM_BYTES" && "$mem" -lt "$MAX_MEM_BYTES" ]] || fail "$PROFILE_NAME memory requirement not met, got $mem"
fi
ok "$PROFILE_NAME hardware profile"

jq . "$ROOT/config/opencode.json" >/dev/null
ok "OpenCode backup config is valid JSON"
/usr/bin/python3 -m py_compile "$ROOT/mcp/local_code_index.py" "$ROOT/mcp/local_dev_tools.py" "$ROOT/mcp/remote_mcp_proxy.py"
ok "MCP Python files compile"
plutil -lint "$ROOT/config/com.ohmz.opencode.env.plist" >/dev/null
ok "LaunchAgent plist is valid"

"$ROOT/scripts/validate-profile-sync.sh"
ok "profile and OpenCode config are in sync"

if [[ "${SMOKE_SKIP_LMSTUDIO:-0}" != "1" ]]; then
  "$ROOT/scripts/ensure-lmstudio-models.sh"
  ok "LM Studio models ensured"

  models="$(curl -s --max-time 10 "$LMSTUDIO_MODELS_URL")"
  printf '%s\n' "$models" | jq -e --arg id "$CHAT_ID" --argjson context "$CHAT_CONTEXT" '.data[] | select(.id == $id and .state == "loaded" and .loaded_context_length == $context)' >/dev/null
  ok "chat model loaded at configured context"
  printf '%s\n' "$models" | jq -e --arg id "$EMBED_ID" '.data[] | select(.id == $id and .state == "loaded")' >/dev/null
  ok "embedding model loaded"

  listener="$(lsof -nP -iTCP:"$LMSTUDIO_PORT" -sTCP:LISTEN)"
  printf '%s\n' "$listener" | grep "$LMSTUDIO_HOST:$LMSTUDIO_PORT" >/dev/null
  if printf '%s\n' "$listener" | grep "0.0.0.0:$LMSTUDIO_PORT" >/dev/null; then
    fail "LM Studio is exposed on 0.0.0.0"
  fi
  ok "LM Studio bound to localhost"

  chat_payload="$(jq -n --arg model "$CHAT_ID" '{
    model: $model,
    messages: [
      {role: "system", content: "You are Qwen, created by Alibaba Cloud. You are a helpful assistant. <|think_off|>"},
      {role: "user", content: "No tools. Reply with exactly: OK local-coder"}
    ],
    max_tokens: 64,
    temperature: 0
  }')"
  reply_json="$(curl -s --max-time 180 "$LMSTUDIO_BASE_URL/chat/completions" \
    -H 'Content-Type: application/json' \
    -d "$chat_payload")"
  reply="$(printf '%s\n' "$reply_json" | jq -r '.choices[0].message.content // .error.message // ""')"
  [[ "$reply" == *"OK local-coder"* || "$reply" == *OK* ]] || fail "chat smoke response was: $reply"
  reasoning="$(printf '%s\n' "$reply_json" | jq -r '.choices[0].message.reasoning_content // ""')"
  [[ -z "$reasoning" || "$reasoning" == "null" ]] || fail "reasoning_content was not empty"
  ok "chat completion with Qwen prelude"

  compact_payload="$(jq -n --arg model "$CHAT_ID" '{
    model: $model,
    messages: [
      {role: "system", content: "You are Qwen, created by Alibaba Cloud. You are a helpful assistant. <|think_off|>"},
      {role: "user", content: "Handle this tool response safely and reply OK only.\n<tool_response>\ncompact summary payload\n</tool_response>"}
    ],
    max_tokens: 64,
    temperature: 0
  }')"
  compact_reply="$(curl -s --max-time 180 "$LMSTUDIO_BASE_URL/chat/completions" \
    -H 'Content-Type: application/json' \
    -d "$compact_payload" | jq -r '.choices[0].message.content // .error.message // ""')"
  [[ "$compact_reply" == *OK* ]] || fail "compaction-style smoke response was: $compact_reply"
  ok "compaction-style prompt rendering"

  embed_payload="$(jq -n --arg model "$EMBED_ID" '{model: $model, input: ["smoke"]}')"
  embed_count="$(curl -s "$LMSTUDIO_EMBEDDING_URL" \
    -H 'Content-Type: application/json' \
    -d "$embed_payload" \
    | jq -r '.data[0].embedding | length')"
  [[ "$embed_count" == "$EMBED_DIMENSIONS" ]] || fail "embedding smoke expected $EMBED_DIMENSIONS dimensions, got $embed_count"
  ok "embedding completion"
else
  ok "LM Studio live checks skipped"
fi

printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  | OPENCODE_INDEX_ROOTS="$OPENCODE_INDEX_ROOTS" OPENCODE_INDEX_AUTODISCOVER="$OPENCODE_INDEX_AUTODISCOVER" OPENCODE_DESKTOP_STATE="$OPENCODE_DESKTOP_STATE" OPENCODE_INDEX_BACKGROUND=0 OPENCODE_INDEX_DB="$OPENCODE_INDEX_DB" LMSTUDIO_EMBEDDING_URL="$LMSTUDIO_EMBEDDING_URL" LMSTUDIO_EMBEDDING_MODEL="$EMBED_ID" \
    python3 "$ROOT/mcp/local_code_index.py" | grep 'code_index_search' >/dev/null
ok "local_code_index MCP"

printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  | OPENCODE_DEV_ROOTS="$OPENCODE_DEV_ROOTS" OPENCODE_DESKTOP_STATE="$OPENCODE_DESKTOP_STATE" \
    python3 "$ROOT/mcp/local_dev_tools.py" | grep 'project_overview' >/dev/null
ok "local_dev_tools MCP"

blocked="$(printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"run_command","arguments":{"command":"rm -rf /tmp/something","cwd":"/tmp","timeout_seconds":5}}}' \
  | OPENCODE_DEV_ROOTS="$OPENCODE_DEV_ROOTS" OPENCODE_DESKTOP_STATE="$OPENCODE_DESKTOP_STATE" \
    python3 "$ROOT/mcp/local_dev_tools.py" | tail -n 1)"
printf '%s\n' "$blocked" | jq -e '.result.isError == true and (.result.content[0].text | contains("blocked by local safety pattern"))' >/dev/null
ok "local_dev_tools destructive command block"

if [[ "${SMOKE_SKIP_REMOTE_MCP:-0}" != "1" ]]; then
  curl -sS --max-time 20 -X POST https://mcp.context7.com/mcp \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -H 'MCP-Protocol-Version: 2024-11-05' \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}' \
    | grep -E 'context7|result|protocolVersion' >/dev/null
  ok "context7 remote MCP"

  curl -sS --max-time 20 -X POST https://mcp.grep.app \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -H 'MCP-Protocol-Version: 2024-11-05' \
    -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' \
    | grep -E 'searchGitHub|tools|result' >/dev/null
  ok "gh_grep remote MCP"
else
  ok "remote MCP live checks skipped"
fi

jq -e '.mcp | keys == ["context7","gh_grep","local_code_index","local_dev_tools"]' "$ROOT/config/opencode.json" >/dev/null
jq -e '.agent | keys == ["build","code-reviewer","codebase-researcher","debugger","doc-researcher","plan","security-auditor","test-runner"]' "$ROOT/config/opencode.json" >/dev/null
jq -e '.command | keys == ["debug","docs","implement","index","research","review","security","test"]' "$ROOT/config/opencode.json" >/dev/null
jq -e '.lsp | keys == ["eslint","typescript"]' "$ROOT/config/opencode.json" >/dev/null
ok "OpenCode MCP, agent, command, and LSP shape"

if [[ "${SMOKE_SKIP_LAUNCHCTL:-0}" != "1" ]]; then
  [[ "$(launchctl getenv OPENCODE_ENABLE_EXA)" == "$OPENCODE_ENABLE_EXA" ]] || fail "OPENCODE_ENABLE_EXA launch env missing"
  [[ "$(launchctl getenv OPENCODE_EXPERIMENTAL_LSP_TOOL)" == "$OPENCODE_EXPERIMENTAL_LSP_TOOL" ]] || fail "OPENCODE_EXPERIMENTAL_LSP_TOOL launch env missing"
  ok "launch environment"
fi

printf '%s\n' "All smoke tests passed."
