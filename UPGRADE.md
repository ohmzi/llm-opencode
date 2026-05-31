# Upgrading This 48 GB Setup

This backup targets the 48 GB Qwen3.6 MLX 8-bit workflow.

To upgrade without losing the working baseline:

1. Edit `/Users/oiqbal/AndroidStudioProjects/llm-opencode/config/profile-48gb.env`.
2. Mirror OpenCode-facing changes in `/Users/oiqbal/AndroidStudioProjects/llm-opencode/config/opencode.json`.
3. Run `/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/validate-profile-sync.sh`.
4. Run `/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/install-opencode-config.sh` on the target 48 GB Mac.
5. Run `/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/ensure-lmstudio-models.sh`.
6. Run `/Users/oiqbal/AndroidStudioProjects/llm-opencode/scripts/smoke-test.sh`.

Use `SMOKE_QWEN_GENERATION=1` only when you deliberately want the slower direct Qwen generation check. The normal smoke follows the production routing design: fast model for no-tool generation, Qwen loaded/configured for coding routes.

Keep these as the 48 GB constraints unless intentionally changing the profile:

- OpenCode default model id: `lmstudio/local-fast`
- OpenCode Qwen coding model id: `lmstudio/local-coder`
- LM Studio fast identifier: `local-fast`
- LM Studio coding identifier: `local-coder`
- Fast model source: `mlx-community/Llama-3.2-3B-Instruct-4bit`
- Model source: `froggeric/qwen3.6-27b-mlx-8bit`
- Model path: `froggeric/Qwen3.6-27B-MLX-8bit`
- Qwen context/output: `32768` / `4096`
- Fast context/output: `32768` / `1024`
- Parallel: `1`
- LM Studio bind: `127.0.0.1:1234`

If Qwen 32K context is unstable, reload the same `local-coder` alias at `24576`, then `16384`. Keep `local-fast` loaded separately so OpenCode does not fall back to manual model swapping.

Do not replace Qwen with Gemma or another model in this profile without a separate experiment and smoke test. Extra models do not add MCP capability by themselves; they only change how well a model uses the already configured tools.

When changing agents or commands, keep these loop-prevention rules unless there is a deliberate new design:

- `default_agent` stays `fast`.
- `build.steps` stays low, currently `18`.
- `plan.steps` stays low, currently `10`.
- `build` denies `local_code_index_*`, `local_dev_tools_*`, `context7_*`, and `gh_grep_*`.
- `/research` is the MCP-backed path.
- `/explain` remains fast/no-tool and conservative for project-specific questions.
- Qwen instructions keep `<|think_off|>` at the top.

Do not copy model weights into this repo. Store identifiers, source paths, runtime URLs, checksums, and scripts so LM Studio remains the place that owns model downloads and updates.

## Ubuntu RTX 3090 Profile

For the separate Ubuntu i9 13th gen, 96 GB RAM, RTX 3090 setup, do not overwrite the 48 GB Mac
defaults. Use the opt-in profile and config instead:

```bash
OPENCODE_BACKUP_PROFILE="$PWD/config/profile-96gb-ubuntu-nvidia.env" \
OPENCODE_BACKUP_CONFIG="$PWD/config/opencode-96gb-ubuntu-nvidia.json" \
scripts/validate-profile-sync.sh
```

Follow `PLAN-96GB-UBUNTU-NVIDIA.md` on the Linux target. That profile keeps `lmstudio/local-coder`,
the same agents, commands, MCPs, RAG, and LSP shape, but changes the chat model to
`Qwen3.6-27B-UD-Q5_K_XL.gguf` through LM Studio's Linux GGUF runtime.
