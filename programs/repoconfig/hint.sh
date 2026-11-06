# shellcheck shell=bash
# The prompt hook that names `repoconfig` on entering a repo it has not been
# run in. Sourced into every interactive bash by configuration.nix. Why a
# prompt hook, and why it has to be cheap, is in default.nix.
#
# This runs in your own shell, so it cannot have a PATH of its own: git is a
# store path in a variable instead, set by default.nix ahead of this with the
# other values. Everything it defines is named __repoconfig_* to stay out of
# the way.

: "${__repoconfig_git:?}" "${__repoconfig_command:?}" "${__repoconfig_prefix:?}"

__repoconfig_hint() {
  local status=$?
  __repoconfig_hint_check
  return $status
}
__repoconfig_hint_check() {
  [ "$PWD" = "${__repoconfig_pwd-}" ] && return
  __repoconfig_pwd=$PWD

  local root
  if ! root=$("$__repoconfig_git" rev-parse --show-toplevel 2>/dev/null); then
    __repoconfig_root=
    return
  fi
  [ "$root" = "${__repoconfig_root-}" ] && return
  __repoconfig_root=$root

  [ -f "$root/mise.toml" ] || [ -f "$root/.mise.toml" ] && return
  [ "$("$__repoconfig_git" -C "$root" config --bool repoconfig.skip 2>/dev/null)" = true ] && return

  printf '\033[1;33mThis repo is not set up yet, run:\033[0m %s\n' "$__repoconfig_command"
  printf '   (%s --help lists every command on this machine)\n' "$__repoconfig_prefix"
}
PROMPT_COMMAND="__repoconfig_hint${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
