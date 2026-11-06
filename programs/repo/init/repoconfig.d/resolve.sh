# shellcheck shell=bash
# Part of repoconfig.sh, inlined into it at build time.
# The steps that need the network, which is why they come last.

# This talks to the network and can take a minute on a fresh preset, so it
# goes at the end: a failure or a ctrl-c here leaves the repo already set up
# rather than half configured.
resolve_and_lock() {
  mise install || say "mise install reported a problem, see above"
  mise lock --platform linux-x64,windows-x64 || say "mise lock reported a problem, see above"
}

# Run the sync here rather than telling you to cd out and back in. The mise
# enter hook lives in the interactive shell, so it cannot be triggered from
# inside this script; calling it directly does the same job. The repo has a
# mise.toml and is trusted by now, so the guard lets it through.
sync_plugins() {
  echo
  vscode-sync
}
