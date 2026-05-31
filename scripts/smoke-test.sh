#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
source "$ROOT/scripts/lib/profile.sh"
require_profile_vars LMS EXPECTED_ARCH MIN_MEM_BYTES MAX_MEM_BYTES LMSTUDIO_HOST LMSTUDIO_PORT LMSTUDIO_BASE_URL LMSTUDIO_MODELS_URL LMSTUDIO_EMBEDDING_URL CHAT_ID CHAT_CONTEXT EMBED_ID OPENCODE_DESKTOP_STATE OPENCODE_INDEX_DB OPENCODE_DEV_ROOTS OPENCODE_INDEX_ROOTS OPENCODE_INDEX_AUTODISCOVER SOURCEKIT_LSP DEVELOPER_DIR

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

[[ "$(uname -m)" == "$EXPECTED_ARCH" ]] || fail "Apple Silicon $EXPECTED_ARCH required"
mem="$(sysctl -n hw.memsize)"
[[ "$mem" -ge "$MIN_MEM_BYTES" && "$mem" -lt "$MAX_MEM_BYTES" ]] || fail "expected about 24 GB RAM, got $mem"
ok "24 GB Apple Silicon profile"

jq . "$ROOT/config/opencode.json" >/dev/null
ok "OpenCode backup config is valid JSON"

"$ROOT/scripts/validate-profile-sync.sh"
ok "profile and OpenCode config are in sync"

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
  messages: [{role: "user", content: "No tools. Reply OK only."}],
  max_tokens: 8,
  temperature: 0
}')"
reply="$(curl -s "$LMSTUDIO_BASE_URL/chat/completions" \
  -H 'Content-Type: application/json' \
  -d "$chat_payload" \
  | jq -r '.choices[0].message.content // .error.message // ""')"
[[ "$reply" == *OK* || "$reply" == *READY* ]] || fail "chat smoke response was: $reply"
ok "chat completion"

embed_payload="$(jq -n --arg model "$EMBED_ID" '{model: $model, input: ["smoke"]}')"
embed_count="$(curl -s "$LMSTUDIO_EMBEDDING_URL" \
  -H 'Content-Type: application/json' \
  -d "$embed_payload" \
  | jq -r '.data[0].embedding | length')"
[[ "$embed_count" -gt 0 ]] || fail "embedding smoke failed"
ok "embedding completion"

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
    python3 "$ROOT/mcp/local_dev_tools.py" | grep 'dev_status' >/dev/null
ok "local_dev_tools MCP"

printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  | PROXY_TARGET=context7 python3 "$ROOT/mcp/remote_mcp_proxy.py" | grep 'context7_resolve' >/dev/null
ok "context7 proxy MCP"

remote_mcp_call_ok \
  "context7" \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"context7_resolve","arguments":{"query":"react","libraryName":"react"}}}' \
  "context7 proxy MCP call"

printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  | PROXY_TARGET=gh_grep python3 "$ROOT/mcp/remote_mcp_proxy.py" | grep 'gh_grep_search' >/dev/null
ok "gh_grep proxy MCP"

remote_mcp_call_ok \
  "gh_grep" \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"gh_grep_search","arguments":{"query":"useState","language":["TypeScript"],"useRegexp":false}}}' \
  "gh_grep proxy MCP call"

[[ -x "$SOURCEKIT_LSP" ]] || fail "sourcekit-lsp missing"
ok "sourcekit-lsp available"

jq -e '.mcp | keys == ["context7","gh_grep","local_code_index","local_dev_tools"]' "$ROOT/config/opencode.json" >/dev/null
jq -e '.agent | keys == ["build","debug","plan","review"]' "$ROOT/config/opencode.json" >/dev/null
jq -e '.command | keys == ["debug","docs","index","reindex","review","search-index"]' "$ROOT/config/opencode.json" >/dev/null
jq -e --arg sourcekit "$SOURCEKIT_LSP" --arg developer "$DEVELOPER_DIR" '.lsp["sourcekit-lsp"].command == [$sourcekit] and .lsp["sourcekit-lsp"].env.DEVELOPER_DIR == $developer' "$ROOT/config/opencode.json" >/dev/null
ok "OpenCode MCP, agent, command, and LSP shape"

printf '%s\n' "All smoke tests passed."
