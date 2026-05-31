# shellcheck shell=zsh

_profile_script_dir="${0:A:h}"
_profile_root="${_profile_script_dir:h}"
if [[ -n "${LLM_OPENCODE_ROOT:-}" ]]; then
  _profile_root="$LLM_OPENCODE_ROOT"
fi

typeset -a _profile_candidates
if [[ -n "${OPENCODE_BACKUP_PROFILE:-}" ]]; then
  _profile_candidates=("$OPENCODE_BACKUP_PROFILE")
else
  _profile_candidates=(
    "$_profile_root/config/profile.env"
    "$_profile_root/config/profile-48gb.env"
    "$_profile_root/config/profile-24gb.env"
    "$_profile_root/config/profile-96gb-ubuntu-nvidia.env"
    "$_profile_script_dir/profile.env"
    "$_profile_script_dir/profile-48gb.env"
    "$_profile_script_dir/profile-24gb.env"
    "$_profile_script_dir/profile-96gb-ubuntu-nvidia.env"
    "$_profile_script_dir/../config/profile.env"
    "$_profile_script_dir/../config/profile-48gb.env"
    "$_profile_script_dir/../config/profile-24gb.env"
    "$_profile_script_dir/../config/profile-96gb-ubuntu-nvidia.env"
    "$_profile_script_dir/../../config/profile.env"
    "$_profile_script_dir/../../config/profile-48gb.env"
    "$_profile_script_dir/../../config/profile-24gb.env"
    "$_profile_script_dir/../../config/profile-96gb-ubuntu-nvidia.env"
    "$HOME/.config/opencode/profile.env"
    "$HOME/.config/opencode/profile-48gb.env"
    "$HOME/.config/opencode/profile-24gb.env"
    "$HOME/.config/opencode/profile-96gb-ubuntu-nvidia.env"
  )
fi

LLM_OPENCODE_PROFILE=""
for _candidate in "${_profile_candidates[@]}"; do
  if [[ -f "$_candidate" ]]; then
    LLM_OPENCODE_PROFILE="$_candidate"
    break
  fi
done

if [[ -z "$LLM_OPENCODE_PROFILE" ]]; then
  echo "Could not locate an OpenCode backup profile. Set OPENCODE_BACKUP_PROFILE to the profile path." >&2
  return 1 2>/dev/null || exit 1
fi

source "$LLM_OPENCODE_PROFILE"

LMSTUDIO_BASE_URL="${LMSTUDIO_BASE_URL:-http://$LMSTUDIO_HOST:$LMSTUDIO_PORT/v1}"
LMSTUDIO_MODELS_URL="${LMSTUDIO_MODELS_URL:-http://$LMSTUDIO_HOST:$LMSTUDIO_PORT/api/v0/models}"
LMSTUDIO_EMBEDDING_URL="${LMSTUDIO_EMBEDDING_URL:-$LMSTUDIO_BASE_URL/embeddings}"
OPENCODE_CONFIG_DIR="${OPENCODE_CONFIG_DIR:-$TARGET_HOME/.config/opencode}"
OPENCODE_CONFIG="${OPENCODE_CONFIG:-$OPENCODE_CONFIG_DIR/opencode.json}"

require_profile_var() {
  local name="$1"
  if [[ -z "${(P)name:-}" ]]; then
    echo "Missing required profile variable: $name" >&2
    return 1
  fi
}

require_profile_vars() {
  local name
  for name in "$@"; do
    require_profile_var "$name" || return 1
  done
}

export LLM_OPENCODE_PROFILE
