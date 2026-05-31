#!/usr/bin/env bash
export OPENCODE_ENABLE_EXA="${OPENCODE_ENABLE_EXA:-1}"
export OPENCODE_EXPERIMENTAL_LSP_TOOL="${OPENCODE_EXPERIMENTAL_LSP_TOOL:-true}"

if [[ "$#" -gt 0 ]]; then
  exec "$@"
fi
