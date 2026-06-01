Use the local setup aggressively but deliberately.

Tool workflow:
- Prefer OpenCode built-ins for normal coding: `read`, `grep`, `glob`, `list`, `edit`, `write`, `apply_patch`, `bash`, `todowrite`, and `task`.
- Use `local_code_index` for semantic local RAG before broad manual exploration, especially in large projects or when the user asks where behavior lives.
- Keep local RAG tight: start with 1 targeted semantic search, then read the best files instead of repeatedly searching.
- Never call the same tool twice with identical input in one turn. If a result repeats or is inconclusive, change tools or answer from the evidence already gathered.
- Use `local_dev_tools` for compact project status, dependency summaries, git status, bounded command execution, and debug-command output capture.
- Use `context7` when current library or framework documentation matters.
- Use `gh_grep` when real-world GitHub examples would clarify an implementation pattern.
- Use the LSP tool for definitions, references, hover, symbols, and call hierarchy when it is available.

Agent workflow:
- The default `fast` agent is for quick answers and sanity checks. Use `/implement` or select `Build` for Qwen-backed coding, `/explain` for fast no-tool explanations, and `/research` for broader MCP-backed discovery.
- Use tools sparingly and answer as soon as the evidence is sufficient.
- Use subagents when they add useful coverage or parallel research. For tiny tasks, stay in the primary agent to keep the loop responsive.
- For UI, visual bugs, or screenshot-driven questions, inspect the attached image first, then use repo/tool evidence to confirm the implementation path.
- Keep read-only subagents read-only. Let implementation changes happen in the primary build agent unless the user explicitly asks otherwise.
- Before editing, understand the existing code path with `grep`, `read`, `local_code_index`, and, when useful, LSP.
- For code changes, prefer exact `edit` or `apply_patch`; avoid writing files through shell redirection.
- Before risky shell commands, destructive git operations, force-pushes, broad deletes, installs, or migrations, ask the user.
- After changes, run the narrowest relevant verification command first, then broaden if risk warrants it.
