# Upgrading This 24 GB Setup

This backup is intentionally concrete to `/Users/ohmz` and this 24 GB MacBook Pro. To upgrade without losing the working baseline:

1. Edit `/Users/ohmz/StudioProjects/llm-opencode/config/profile-24gb.env`.
2. Mirror any OpenCode-facing changes in `/Users/ohmz/StudioProjects/llm-opencode/config/opencode.json`.
3. Run `/Users/ohmz/StudioProjects/llm-opencode/scripts/validate-profile-sync.sh`.
4. Run `/Users/ohmz/StudioProjects/llm-opencode/scripts/install-opencode-config.sh`.
5. Run `/Users/ohmz/StudioProjects/llm-opencode/scripts/ensure-lmstudio-models.sh`.
6. Run `/Users/ohmz/StudioProjects/llm-opencode/scripts/smoke-test.sh`.

Keep these as one-model 24 GB constraints unless intentionally changing the profile:

- Chat model id: `qwen3.6-27b`
- Model source/path: `NexVeridian/Qwen3.6-27B-3bit`
- Context: `12288`
- Output: `768`
- Parallel: `1`
- LM Studio bind: `127.0.0.1:1234`

Do not copy model weights into this repo. Store identifiers, source paths, runtime URLs, checksums, and scripts so LM Studio remains the place that owns model downloads and updates.
