"""Read one array out of a project's .vscode/extensions.json.

Called by programs/vscode.nix. That file is JSONC: comments and trailing
commas are legal and worth keeping, which is why this is not jq.

Usage: vscode-extensions-json.py <file> <key>
Prints one entry per line. A malformed file warns and yields nothing,
so a typo in a project's config cannot break entering the directory.
"""

import sys

import json5


def main() -> int:
    path, key = sys.argv[1], sys.argv[2]
    try:
        with open(path) as handle:
            data = json5.load(handle)
    except Exception as exc:
        print(f"[vscode] WARNING: could not parse {path}: {exc}", file=sys.stderr)
        return 0

    if not isinstance(data, dict):
        print(f"[vscode] WARNING: {path} is not an object", file=sys.stderr)
        return 0

    for item in data.get(key) or []:
        if isinstance(item, str):
            print(item)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
