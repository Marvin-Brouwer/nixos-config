# shellcheck shell=bash
# `highlight`: colours every `backticked` span in its argument, backticks kept,
# so a command a message tells you to run stands out from the prose around it.
# Inlined into a command's script at build time like any other part; see
# shell-script.nix. The plain-text notices keep the backticks and skip this.

highlight() {
  local text=$1 out=""
  while [[ $text == *'`'*'`'* ]]; do
    out+=${text%%'`'*}
    text=${text#*'`'}
    out+=$'\033[1;36m`'"${text%%'`'*}"$'`\033[0m'
    text=${text#*'`'}
  done
  printf '%s' "$out$text"
}
