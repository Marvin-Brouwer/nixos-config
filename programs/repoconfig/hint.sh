# shellcheck shell=bash
# The prompt hook that names `repoconfig` on entering a repo it has not been
# run in. Sourced into every interactive bash by configuration.nix, after
# default.nix fills in the @-delimited placeholders. Why a prompt hook, and
# why it has to be cheap, is in default.nix.

__repoconfig_hint() {
  local status=$?
  __repoconfig_hint_check
  return $status
}
__repoconfig_hint_check() {
  [ "$PWD" = "${__repoconfig_pwd-}" ] && return
  __repoconfig_pwd=$PWD

  local root
  if ! root=$(@git@/bin/git rev-parse --show-toplevel 2>/dev/null); then
    __repoconfig_root=
    return
  fi
  [ "$root" = "${__repoconfig_root-}" ] && return
  __repoconfig_root=$root

  [ -f "$root/mise.toml" ] || [ -f "$root/.mise.toml" ] && return
  [ "$(@git@/bin/git -C "$root" config --bool repoconfig.skip 2>/dev/null)" = true ] && return

  printf '\033[1;33mThis repo is not set up yet, run:\033[0m %s\n' "@command@"
  printf '   (@prefix@ --help lists every command on this machine)\n'
}
PROMPT_COMMAND="__repoconfig_hint${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
