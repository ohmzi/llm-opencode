 48 GB macOS Local Agentic Coding Setup: Qwen3.6 MLX 8-bit + OpenCode MCP/RAG Workflow
​
## Summary
Set up LM Studio and OpenCode Desktop on an Apple Silicon Mac with 48 GB RAM using one primary local coding model:
​
`froggeric/qwen3.6-27b-mlx-8bit` loaded as `local-coder`.
​
Use this instead of Qwen3-Coder because the target setup is a larger high-quality **MLX-native Qwen3.6** workflow. The model is about `28 GB`, lists about `35 GB` minimum system memory, includes LM Studio tool-calling/developer-role template support, and should fit a 48 GB Mac with a 32K working context.
​
The OpenCode side should be configured as a full local agentic coding environment:
​
- One visible model: `lmstudio/local-coder`
- Four MCP servers:
  - `context7` for current framework/library docs
  - `gh_grep` for real-world GitHub code examples
  - `local_code_index` for local semantic RAG over OpenCode projects
  - `local_dev_tools` for compact execute/debug/project/git/dependency utilities
- Two LSP integrations visible in OpenCode:
  - `typescript`
  - `eslint`
- Subagents and slash commands for research, debugging, tests, review, docs, security, indexing, and implementation.
- Safer permissions: file edits allowed, common read/test commands allowed, unknown shell commands ask, risky/destructive commands blocked or ask.
​
Sources:
- [LM Studio Qwen3.6 MLX 8-bit](https://lmstudio.ai/froggeric/qwen3.6-27b-mlx-8bit)
- [Hugging Face froggeric/Qwen3.6-27B-MLX-8bit](https://huggingface.co/froggeric/Qwen3.6-27B-MLX-8bit)
- [OpenCode config docs](https://opencode.ai/docs/config)
- [OpenCode tools docs](https://opencode.ai/docs/tools)
- [OpenCode agents docs](https://opencode.ai/docs/agents/)
- [OpenCode commands docs](https://opencode.ai/docs/commands/)
- [OpenCode MCP docs](https://opencode.ai/docs/mcp-servers/)
​
## Target Installed State
- Official apps only:
  - LM Studio from `https://lmstudio.ai/download`
  - OpenCode Desktop from `https://opencode.ai/download`
  - Do not install Homebrew as part of this setup.
- LM Studio app:
  - `/Applications/LM Studio.app`
  - Verified version used during setup: `0.4.15+2`
- OpenCode Desktop app:
  - `/Applications/OpenCode.app`
  - Verified version used during setup: `1.15.12`
- OpenCode config:
  - `~/.config/opencode/opencode.json`
  - `~/.config/opencode/qwen36-instructions.md`
  - `~/.config/opencode/local-coding-workflow.md`
  - `~/.config/opencode/mcp/local_code_index.py`
  - `~/.config/opencode/mcp/local_dev_tools.py`
- Local semantic index:
  - `~/.cache/opencode/local-code-index.sqlite3`
- Persistent GUI launch environment:
  - `~/Library/LaunchAgents/com.oiqbal.opencode.env.plist`
  - `~/.config/opencode/opencode-launch-env.sh`
​
## Preflight
```bash
test "$(uname -m)" = "arm64"
sysctl -n hw.memsize
command -v jq
command -v lms
```
​
Expected:
- `uname -m` is `arm64`
- Memory is about `51539607552` bytes for a 48 GB Mac
- `jq` works
- `lms` works from LM Studio
​
## Download And Load Qwen3.6 MLX 8-bit
```bash
lms get froggeric/qwen3.6-27b-mlx-8bit --mlx --yes
​
MODEL_KEY="$(lms ls --json | jq -r '.[] | select(.path=="froggeric/Qwen3.6-27B-MLX-8bit" or .indexedModelIdentifier=="froggeric/qwen3.6-27b-mlx-8bit" or .modelKey=="froggeric/qwen3.6-27b-mlx-8bit").modelKey' | head -1)"
test -n "$MODEL_KEY"
​
lms unload --all || true
lms load "$MODEL_KEY" \
  --identifier local-coder \
  --context-length 32768 \
  --gpu max \
  --parallel 1 \
  --ttl 3600 \
  --yes
```
​
Keep LM Studio local-only:
​
- Server: `127.0.0.1:1234`
- No LAN exposure
- Listener must be `127.0.0.1:1234`, not `0.0.0.0:1234`
​
## Qwen Instruction Prelude
Create `~/.config/opencode/qwen36-instructions.md`:
​
```md
You are Qwen, created by Alibaba Cloud. You are a helpful assistant. <|think_off|>
​
Follow OpenCode's tool-use and coding instructions exactly. Keep tool calls valid, concise, and compatible with OpenAI-style tool calling.
```
​
This instruction is important because raw Qwen API calls can otherwise spend output tokens in `reasoning_content`. The OpenCode setup should always include this instruction file.
​
## Local Coding Workflow Instruction
Create `~/.config/opencode/local-coding-workflow.md`:
​
```md
Use the local setup aggressively but deliberately.
​
Tool workflow:
- Prefer OpenCode built-ins for normal coding: `read`, `grep`, `glob`, `list`, `edit`, `write`, `apply_patch`, `bash`, `todowrite`, and `task`.
- Use `local_code_index` for semantic local RAG before broad manual exploration, especially in large projects or when the user asks where behavior lives.
- Use `local_dev_tools` for compact project status, dependency summaries, git status, bounded command execution, and debug-command output capture.
- Use `context7` when current library or framework documentation matters.
- Use `gh_grep` when real-world GitHub examples would clarify an implementation pattern.
- Use the LSP tool for definitions, references, hover, symbols, and call hierarchy when it is available.
​
Agent workflow:
- Use subagents for parallel research, code review, debugging, security review, documentation lookup, and test planning.
- Keep read-only subagents read-only. Let implementation changes happen in the primary build agent unless the user explicitly asks otherwise.
- Before editing, understand the existing code path with `grep`, `read`, `local_code_index`, and, when useful, LSP.
- For code changes, prefer exact `edit` or `apply_patch`; avoid writing files through shell redirection.
- Before risky shell commands, destructive git operations, force-pushes, broad deletes, installs, or migrations, ask the user.
- After changes, run the narrowest relevant verification command first, then broaden if risk warrants it.
```
​
## OpenCode Config
Create or update `~/.config/opencode/opencode.json`.
​
The important top-level behavior:
​
```json
{
  "$schema": "https://opencode.ai/config.json",
  "enabled_providers": ["lmstudio"],
  "default_agent": "build",
  "instructions": [
    "/Users/oiqbal/.config/opencode/qwen36-instructions.md",
    "/Users/oiqbal/.config/opencode/local-coding-workflow.md"
  ],
  "provider": {
    "lmstudio": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "LM Studio (local)",
      "whitelist": ["local-coder"],
      "options": {
        "baseURL": "http://127.0.0.1:1234/v1",
        "apiKey": "lmstudio",
        "timeout": 900000,
        "chunkTimeout": 900000
      },
      "models": {
        "local-coder": {
          "name": "Qwen3.6 27B MLX 8-bit (local, 32K)",
          "tool_call": true,
          "limit": {
            "context": 32768,
            "output": 4096
          }
        }
      }
    }
  },
  "model": "lmstudio/local-coder",
  "small_model": "lmstudio/local-coder",
  "share": "disabled",
  "autoupdate": "notify",
  "formatter": true,
  "lsp": true,
  "snapshot": true,
  "compaction": {
    "auto": true,
    "prune": true,
    "reserved": 10000
  }
}
```
​
Also include watcher ignores:
​
```json
{
  "watcher": {
    "ignore": [
      ".git/**",
      "node_modules/**",
      "dist/**",
      "build/**",
      ".gradle/**",
      "DerivedData/**",
      "Pods/**",
      ".venv/**",
      "target/**",
      ".cache/**",
      ".lmstudio/**"
    ]
  }
}
```
​
## Permissions
Use permissions that make common coding work fast while keeping risky shell actions gated.
​
Recommended shape:
​
```json
{
  "permission": {
    "read": "allow",
    "edit": "allow",
    "glob": "allow",
    "grep": "allow",
    "list": "allow",
    "task": "allow",
    "todowrite": "allow",
    "question": "allow",
    "webfetch": "allow",
    "websearch": "allow",
    "lsp": "allow",
    "skill": "allow",
    "external_directory": "ask",
    "repo_clone": "ask",
    "repo_overview": "allow",
    "doom_loop": "ask",
    "local_code_index_*": "allow",
    "local_dev_tools_project_overview": "allow",
    "local_dev_tools_git_status": "allow",
    "local_dev_tools_file_tree": "allow",
    "local_dev_tools_dependency_summary": "allow",
    "local_dev_tools_run_command": "ask",
    "local_dev_tools_debug_command": "ask",
    "context7_*": "allow",
    "gh_grep_*": "allow",
    "bash": {
      "*": "ask",
      "pwd": "allow",
      "ls": "allow",
      "ls *": "allow",
      "git status*": "allow",
      "git diff*": "allow",
      "git log*": "allow",
      "git branch*": "allow",
      "git rev-parse*": "allow",
      "rg *": "allow",
      "grep *": "allow",
      "cat *": "allow",
      "sed -n *": "allow",
      "npm test*": "allow",
      "npm run test*": "allow",
      "pnpm test*": "allow",
      "pnpm run test*": "allow",
      "yarn test*": "allow",
      "python -m pytest*": "allow",
      "pytest*": "allow",
      "swift test*": "allow",
      "./gradlew test*": "allow",
      "gradle test*": "allow",
      "go test*": "allow",
      "cargo test*": "allow",
      "xcodebuild -list*": "allow"
    }
  }
}
```
​
## MCP Servers
OpenCode should show four MCP servers:
​
1. `context7`
2. `gh_grep`
3. `local_code_index`
4. `local_dev_tools`
​
Add this under `mcp` in `opencode.json`:
​
```json
{
  "mcp": {
    "local_code_index": {
      "type": "local",
      "command": [
        "/usr/bin/python3",
        "/Users/oiqbal/.config/opencode/mcp/local_code_index.py"
      ],
      "environment": {
        "OPENCODE_INDEX_ROOTS": "auto",
        "OPENCODE_INDEX_AUTODISCOVER": "1",
        "OPENCODE_DESKTOP_STATE": "/Users/oiqbal/Library/Application Support/ai.opencode.desktop/opencode.global.dat",
        "OPENCODE_INDEX_BACKGROUND": "1",
        "OPENCODE_INDEX_BACKGROUND_SECONDS": "300",
        "OPENCODE_INDEX_DB": "/Users/oiqbal/.cache/opencode/local-code-index.sqlite3",
        "LMSTUDIO_EMBEDDING_URL": "http://127.0.0.1:1234/v1/embeddings",
        "LMSTUDIO_EMBEDDING_MODEL": "text-embedding-nomic-embed-text-v1.5"
      },
      "enabled": true,
      "timeout": 600000
    },
    "local_dev_tools": {
      "type": "local",
      "command": [
        "/usr/bin/python3",
        "/Users/oiqbal/.config/opencode/mcp/local_dev_tools.py"
      ],
      "environment": {
        "LOCAL_DEV_COMMAND_TIMEOUT": "120",
        "LOCAL_DEV_MAX_TIMEOUT": "600",
        "LOCAL_DEV_MAX_OUTPUT_CHARS": "24000",
        "LOCAL_DEV_MAX_TREE_ENTRIES": "400"
      },
      "enabled": true,
      "timeout": 600000
    },
    "context7": {
      "type": "remote",
      "url": "https://mcp.context7.com/mcp",
      "enabled": true,
      "timeout": 600000
    },
    "gh_grep": {
      "type": "remote",
      "url": "https://mcp.grep.app",
      "enabled": true,
      "timeout": 600000
    }
  }
}
```
​
### `local_code_index` MCP
Add `~/.config/opencode/mcp/local_code_index.py`.
​
It must:
​
- Expose `code_index_status`, `code_index_refresh`, and `code_index_search`.
- Store chunks and embeddings in SQLite at `~/.cache/opencode/local-code-index.sqlite3`.
- Use LM Studio embeddings via `http://127.0.0.1:1234/v1/embeddings`.
- Use `text-embedding-nomic-embed-text-v1.5`.
- Auto-discover current and future OpenCode Desktop projects from `~/Library/Application Support/ai.opencode.desktop/opencode.global.dat`.
- Decode escaped project paths from OpenCode Desktop state.
- Refresh in the background every `300` seconds.
- Refresh opportunistically before search if the last sync is stale.
- Remove stale indexed roots when projects disappear from OpenCode.
- Ignore `.git`, `node_modules`, `build`, `dist`, `.gradle`, `DerivedData`, `Pods`, `.venv`, `target`, `.cache`, and large/binary files.
- Index common code/document text files including Swift, Kotlin, Java, JS/TS, Python, JSON, Markdown, XML, YAML, Gradle, plist, shell, SQL, and README/Makefile-style files.
​
### `local_dev_tools` MCP
Add `~/.config/opencode/mcp/local_dev_tools.py`.
​
It must expose:
​
- `project_overview`
  - Summarizes project root, git root, marker files, detected languages, and likely test/build commands.
- `git_status`
  - Returns branch/status, diff stats, staged diff stats, and recent commits.
- `run_command`
  - Runs bounded shell commands for local build/test/debug work.
  - Blocks obviously destructive commands such as `sudo`, `rm -rf`, `git reset --hard`, destructive `git clean`, force-push, `diskutil`, `dd of=/dev`, `mkfs`, reboot/shutdown, and `curl | sh`.
- `debug_command`
  - Runs a command and tags common failure signals like traceback, JS stack, test failure, timeout, missing dependency, and permission error.
- `file_tree`
  - Returns a shallow project tree while ignoring dependency/build/cache folders.
- `dependency_summary`
  - Summarizes build/dependency metadata such as `package.json`, `pyproject.toml`, `Package.swift`, Gradle, Cargo, Go, Gemfile, and Podfile.
​
### Remote MCPs
- `context7`
  - Use for current docs and examples for frameworks, SDKs, libraries, CLIs, and APIs.
  - Expected tools include `resolve-library-id` and `query-docs`.
- `gh_grep`
  - Use for literal GitHub code search and real-world implementation examples.
  - Expected tool includes `searchGitHub`.
​
## Agents
Add these under `agent` in `opencode.json`.
​
### `build`
- Primary/default implementation agent.
- Edits files, coordinates subagents, runs narrow verification.
- Model: `lmstudio/local-coder`
- Temperature: `0.2`
- Steps: `80`
​
### `plan`
- Primary read-only planning agent.
- Decomposes work, identifies risks, suggests verification.
- Does not edit files.
- Model: `lmstudio/local-coder`
- Temperature: `0.1`
- Steps: `35`
​
### `codebase-researcher`
- Subagent.
- Finds where behavior lives.
- Uses local RAG, grep/glob/read, file tree, dependency summaries, and LSP.
- Read-only.
​
### `debugger`
- Subagent.
- Debugs failing commands, tests, runtime errors, stack traces, and reproduction paths.
- Uses `debug_command` and safe test commands.
- Read-only unless the primary agent explicitly asks otherwise.
​
### `test-runner`
- Subagent.
- Detects project type and runs the narrowest useful validation first.
- Read-only.
​
### `code-reviewer`
- Subagent.
- Reviews diffs and code paths for bugs, regressions, maintainability, missing tests, and security concerns.
- Read-only.
​
### `doc-researcher`
- Subagent.
- Uses `context7`, `gh_grep`, web fetch, and web search for current docs and real-world examples.
- Read-only.
​
### `security-auditor`
- Subagent.
- Reviews input validation, auth, secrets, injection, unsafe filesystem/shell use, and dependency risk.
- Read-only.
​
## Commands
Add these under `command` in `opencode.json`.
​
- `/research`
  - Agent: `codebase-researcher`
  - Subtask: `true`
  - Use local RAG, grep/glob/read, local dev tools, and LSP.
- `/debug`
  - Agent: `debugger`
  - Subtask: `true`
  - Reproduce narrowly, capture output, return root cause and fix options.
- `/test`
  - Agent: `test-runner`
  - Subtask: `true`
  - Detect project type and run narrow validation.
- `/review`
  - Agent: `code-reviewer`
  - Subtask: `true`
  - Review current changes or target files.
- `/docs`
  - Agent: `doc-researcher`
  - Subtask: `true`
  - Query current docs and real-world examples.
- `/security`
  - Agent: `security-auditor`
  - Subtask: `true`
  - Run a read-only security audit.
- `/index`
  - Agent: `build`
  - Inspect and refresh local semantic index.
- `/implement`
  - Agent: `build`
  - Research, edit, and verify end to end.
​
## LSP And Built-In Search
Enable OpenCode LSP and built-in web search for the Desktop app:
​
```bash
launchctl setenv OPENCODE_ENABLE_EXA 1
launchctl setenv OPENCODE_EXPERIMENTAL_LSP_TOOL true
```
​
Persist it across login with `~/.config/opencode/opencode-launch-env.sh`:
​
```bash
#!/bin/zsh
​
/bin/launchctl setenv OPENCODE_ENABLE_EXA 1
/bin/launchctl setenv OPENCODE_EXPERIMENTAL_LSP_TOOL true
```
​
Create `~/Library/LaunchAgents/com.oiqbal.opencode.env.plist`:
​
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.oiqbal.opencode.env</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/oiqbal/.config/opencode/opencode-launch-env.sh</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/com.oiqbal.opencode.env.out</string>
  <key>StandardErrorPath</key>
  <string>/tmp/com.oiqbal.opencode.env.err</string>
</dict>
</plist>
```
​
Load it:
​
```bash
chmod 755 ~/.config/opencode/opencode-launch-env.sh
plutil -lint ~/Library/LaunchAgents/com.oiqbal.opencode.env.plist
launchctl bootout "gui/$(id -u)" ~/Library/LaunchAgents/com.oiqbal.opencode.env.plist >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" ~/Library/LaunchAgents/com.oiqbal.opencode.env.plist
launchctl kickstart -k "gui/$(id -u)/com.oiqbal.opencode.env"
```
​
Expected OpenCode UI after launch:
​
- `4 MCP`
  - `context7`
  - `gh_grep`
  - `local_code_index`
  - `local_dev_tools`
- `2 LSP`
  - `typescript`
  - `eslint`
​
## RAG Seeding
After OpenCode Desktop has been opened once and has a project in:
​
`~/Library/Application Support/ai.opencode.desktop/opencode.global.dat`
​
refresh the local semantic index:
​
```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"code_index_refresh","arguments":{"force":false}}}' \
  | /usr/bin/python3 ~/.config/opencode/mcp/local_code_index.py
```
​
Expected:
​
- It discovers OpenCode Desktop projects automatically.
- It embeds chunks through LM Studio using `text-embedding-nomic-embed-text-v1.5`.
- It writes to `~/.cache/opencode/local-code-index.sqlite3`.
​
Example verified state from setup:
​
- Project: `/Users/oiqbal/Development/Immaculaterr`
- Files indexed: `432`
- Chunks indexed: `1932`
- DB size: about `39M`
​
Smoke test search:
​
```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"code_index_search","arguments":{"query":"app version update","limit":3}}}' \
  | /usr/bin/python3 ~/.config/opencode/mcp/local_code_index.py
```
​
Expected:
​
- `embedding_error` is `null`
- Results include relevant local files and snippets.
​
## Test Plan
Validate config:
​
```bash
jq . ~/.config/opencode/opencode.json >/dev/null
/usr/bin/python3 -m py_compile ~/.config/opencode/mcp/local_code_index.py ~/.config/opencode/mcp/local_dev_tools.py
plutil -lint ~/Library/LaunchAgents/com.oiqbal.opencode.env.plist
```
​
Verify launch environment:
​
```bash
launchctl getenv OPENCODE_ENABLE_EXA
launchctl getenv OPENCODE_EXPERIMENTAL_LSP_TOOL
```
​
Expected:
​
- `OPENCODE_ENABLE_EXA=1`
- `OPENCODE_EXPERIMENTAL_LSP_TOOL=true`
​
Verify LM Studio and local binding:
​
```bash
lms status
lms ps
curl -s http://127.0.0.1:1234/v1/models | jq -r '.data[].id'
lsof -nP -iTCP:1234 -sTCP:LISTEN
```
​
Expected:
​
- Server is on port `1234`
- Loaded models include:
  - `local-coder`
  - `text-embedding-nomic-embed-text-v1.5`
- Listener is `127.0.0.1:1234`, not `0.0.0.0:1234`
​
Smoke test normal generation with Qwen instruction:
​
```bash
curl -sS --max-time 180 http://127.0.0.1:1234/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "local-coder",
    "messages": [
      {
        "role": "system",
        "content": "You are Qwen, created by Alibaba Cloud. You are a helpful assistant. <|think_off|>"
      },
      {
        "role": "user",
        "content": "No tools. Reply with exactly: OK local-coder"
      }
    ],
    "max_tokens": 64,
    "temperature": 0
  }' | jq .
```
​
Expected:
​
- Assistant content is `OK local-coder`
- `reasoning_content` is empty
​
Smoke test OpenCode-compaction-style prompt rendering:
​
```bash
curl -sS --max-time 180 http://127.0.0.1:1234/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "local-coder",
    "messages": [
      {
        "role": "system",
        "content": "You are Qwen, created by Alibaba Cloud. You are a helpful assistant. <|think_off|>"
      },
      {
        "role": "user",
        "content": "Handle this tool response safely and reply OK only.\n<tool_response>\ncompact summary payload\n</tool_response>"
      }
    ],
    "max_tokens": 64,
    "temperature": 0
  }' | jq .
```
​
Expected:
​
- No Jinja/template error
- No LM Studio crash
​
Smoke test embeddings:
​
```bash
curl -sS --max-time 60 http://127.0.0.1:1234/v1/embeddings \
  -H 'Content-Type: application/json' \
  -d '{"model":"text-embedding-nomic-embed-text-v1.5","input":"hello"}' \
  | jq '.data[0].embedding | length'
```
​
Expected:
​
- `768`
​
Smoke test `local_code_index` MCP:
​
```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"code_index_status","arguments":{}}}' \
  | /usr/bin/python3 ~/.config/opencode/mcp/local_code_index.py
```
​
Expected tools:
​
- `code_index_status`
- `code_index_refresh`
- `code_index_search`
​
Smoke test `local_dev_tools` MCP:
​
```bash
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"run_command","arguments":{"command":"pwd","cwd":"/Users/oiqbal/Development/locallmstudiosetup","timeout_seconds":5}}}' \
  '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"run_command","arguments":{"command":"rm -rf /tmp/something","cwd":"/Users/oiqbal/Development/locallmstudiosetup","timeout_seconds":5}}}' \
  | /usr/bin/python3 ~/.config/opencode/mcp/local_dev_tools.py
```
​
Expected:
​
- `pwd` succeeds.
- `rm -rf /tmp/something` is blocked by the local safety pattern.
​
Smoke test remote MCPs:
​
```bash
curl -sS --max-time 20 -X POST https://mcp.context7.com/mcp \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H 'MCP-Protocol-Version: 2024-11-05' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"1"}}}'
​
curl -sS --max-time 20 -X POST https://mcp.grep.app \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json, text/event-stream' \
  -H 'MCP-Protocol-Version: 2024-11-05' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}'
```
​
Expected:
​
- `context7` initializes and lists docs tools.
- `gh_grep` lists `searchGitHub`.
​
OpenCode Desktop smoke test:
​
- Launch `/Applications/OpenCode.app`.
- Confirm MCP tab shows:
  - `context7`
  - `gh_grep`
  - `local_code_index`
  - `local_dev_tools`
- Confirm LSP tab shows:
  - `typescript`
  - `eslint`
- Select `LM Studio (local) / Qwen3.6 27B MLX 8-bit (local, 32K)`.
- Prompt: `No tools. Reply with OK and the model id you are using.`
- Prompt: `/research where is app version defined?`
- Prompt: `/index refresh and search for app version update`
- Prompt: `/debug run the narrowest test command for this project and explain failures`
- Prompt: `/docs look up current Vite env variable typing docs`
- Prompt: `/review current changes`
​
## Operational Notes
- Keep only one visible OpenCode model: `lmstudio/local-coder`.
- Use `local_code_index` before broad exploration in large repositories.
- Use `codebase-researcher`, `doc-researcher`, `debugger`, `test-runner`, `code-reviewer`, and `security-auditor` as subtasks instead of putting every concern in the main agent.
- Use `local_dev_tools_run_command` and `local_dev_tools_debug_command` for compact structured output, but let OpenCode's built-in `bash` handle normal shell workflows when needed.
- Keep destructive commands behind `ask`.
- Keep external-directory access behind `ask`.
- If disk space is low, do not add more large models. This setup already uses about `28 GB` for Qwen3.6 plus index/database overhead.
- If 32K context is unstable, reload the same model alias at `24576`, then `16384`; keep the OpenCode model id as `local-coder`.
- If the 8-bit model cannot load even at 16K, replace it with the same publisher's 4-bit MLX model rather than adding a second visible mo