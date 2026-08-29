# -----------------------------------------------------------------
# My personal base VSCode plugin list.
#
# These are the ones I want everywhere regardless of what a project is
# written in. They are mine, not a project's, so they never belong in a
# repo's .vscode/extensions.json.
#
# A project's own plugins live in its .vscode/extensions.json, which is
# the standard file VSCode already prompts contributors to install.
# programs/vscode.nix unions the two, so this list is the "on top of my
# default profile" half.
#
# Marketplace IDs, publisher.name format.
#
# TODO: this list is still carried over verbatim from the old
# templates/vscode.nix and mixes in a few genuinely project-level
# plugins (eslint, prettier, EditorConfig, redhat.vscode-yaml). Those
# belong in each repo's extensions.json instead. Prune them when writing
# docs/examples/ts.md, deliberately rather than in passing.
# -----------------------------------------------------------------

[
  "jnoortheen.nix-ide"
  "dbaeumer.vscode-eslint"
  "esbenp.prettier-vscode"
  "streetsidesoftware.code-spell-checker"
  "streetsidesoftware.code-spell-checker-dutch"
  "mechatroner.rainbow-csv"
  "qiaojie.binary-viewer" # Maybe also test ms-vscode.hexeditor
  "anseki.vscode-color"
  "EditorConfig.EditorConfig"
  "unifiedjs.vscode-remark"
  "tomoki1207.pdf"
  "DotJoshJohnson.xml"
  "redhat.vscode-yaml"
  "hagent.json-field-filter"
  "oliversturm.fix-json"
  "richie5um2.vscode-statusbar-json-path"
  "motivesoft.vscode-restart"
  "anweber.vscode-httpyac"
  # This is very similar to what we want to do:
  # https://marketplace.visualstudio.com/items?itemName=RhaldKhein.vscode-xrest-client
  # We'd like something in between httpyac and xrest-client
  "dotenv.dotenv-vscode"
  "Tyriar.sort-lines"
  "vscode-icons-team.vscode-icons"
  "joshuapoehls.json-escaper"
  "ExodiusStudios.comment-anchors" # We don't like how in your face todo-tree is, and this saves also having to install todo-highlight
  "stuart.unique-window-colors"
  "vincaslt.highlight-matching-tag" # This one is a try-out, maybe we don't like it
  "wmaurer.change-case"
  "formulahendry.auto-rename-tag"
  "kisstkondoros.vscode-gutter-preview"
  "midudev.better-svg" # or https://marketplace.visualstudio.com/items?itemName=SimonSiefke.svg-preview
  "mads-hartmann.bash-ide-vscode"
  "pomdtr.excalidraw-editor"
  "MermaidChart.vscode-mermaid-chart"
  "DutchIgor.json-viewer" # This one is a try-out, maybe we don't like it
  "Tion.evenbettercomments"
  # Maybe? https://marketplace.visualstudio.com/items?itemName=korostylov.gherkin-highlight
  "funkyremi.vscode-google-translate"
  "hediet.debug-visualizer"
  "heaths.vscode-guid"
  # Maybe? https://marketplace.visualstudio.com/items?itemName=HyunKyunMoon.gzipdecompressor
  "lamartire.git-indicators"
  "meronz.manpages"
  "maattdd.gitless" # or eamodio.gitlens
  "anthropic.claude-code"
]
