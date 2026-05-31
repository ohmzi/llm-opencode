# Upgrading This 48 GB Setup

This backup targets the 48 GB Qwen3.6 MLX 8-bit workflow.

To upgrade without losing the working baseline:

1. Edit `/Users/ohmz/StudioProjects/llm-opencode/config/profile-48gb.env`.
2. Mirror OpenCode-facing changes in `/Users/ohmz/StudioProjects/llm-opencode/config/opencode.json`.
3. Run `/Users/ohmz/StudioProjects/llm-opencode/scripts/validate-profile-sync.sh`.
4. Run `/Users/ohmz/StudioProjects/llm-opencode/scripts/install-opencode-config.sh` on the target 48 GB Mac.
5. Run `/Users/ohmz/StudioProjects/llm-opencode/scripts/ensure-lmstudio-models.sh`.
6. Run `/Users/ohmz/StudioProjects/llm-opencode/scripts/smoke-test.sh`.

Keep these as the 48 GB constraints unless intentionally changing the profile:

- OpenCode model id: `lmstudio/local-coder`
- LM Studio model identifier: `local-coder`
- Model source: `froggeric/qwen3.6-27b-mlx-8bit`
- Model path: `froggeric/Qwen3.6-27B-MLX-8bit`
- Context: `32768`
- Output: `4096`
- Parallel: `1`
- LM Studio bind: `127.0.0.1:1234`

If 32K context is unstable, reload the same `local-coder` alias at `24576`, then `16384`. Do not add a second visible OpenCode model unless explicitly changing the workflow.

Do not copy model weights into this repo. Store identifiers, source paths, runtime URLs, checksums, and scripts so LM Studio remains the place that owns model downloads and updates.
