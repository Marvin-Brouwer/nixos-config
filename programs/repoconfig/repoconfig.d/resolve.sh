# shellcheck shell=bash
# Part of repoconfig.sh, inlined into it in order at build time.
# mise install, mise lock and the plugin sync: the only steps that need
# the network.

# --- resolve and lock, last ---
# Everything above is local and instant. This talks to the network and can
# take a minute on a fresh preset, so it goes at the end: a failure or a
# ctrl-c here leaves the repo already set up rather than half configured.
mise install || say "mise install reported a problem, see above"
mise lock --platform linux-x64,windows-x64 || say "mise lock reported a problem, see above"

# Run the sync here rather than telling you to cd out and back in. The mise
# enter hook lives in the interactive shell, so it cannot be triggered from
# inside this script; calling it directly does the same job. The repo has a
# mise.toml and is trusted by now, so the guard lets it through.
echo
vscode-sync

printf '\n   Done.\n\n'
