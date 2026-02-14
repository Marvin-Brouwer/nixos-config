# -----------------------------------------------------------------
# Base list of VSCode extension IDs that all profiles inherit.
#
# These are marketplace extension IDs (publisher.name format).
# The dev shell installs them into a named VSCode Profile via
# `code --install-extension` and launches VSCode with that profile.
# -----------------------------------------------------------------

{ extra ? [] }:

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
  "oderwat.indent-rainbow" # if this is too much, check https://marketplace.visualstudio.com/items?itemName=tal7aouy.rainbow-bracket
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
] ++ extra
