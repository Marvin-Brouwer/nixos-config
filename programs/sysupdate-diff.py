"""Turn two Nix closures into the pending-update notice.

Called by programs/sysupdate.nix, from the sysupdate-check systemd unit.

Input is two lists of store paths: the running system's runtime closure and
the *derivation* closure of the system that would be built against the newer
inputs. Comparing names that appear in both is what makes this cheap -- it
downloads nothing, because a .drv is enough to know a package's version.

The consequence is that only version changes are reported. A name on one side
only (a package added, a package dropped, a build-time-only dependency) has
nothing to compare against and is left out, as is anything whose version is not
version-shaped -- see VERSION below, which together with ALPHA_TAIL is what
keeps source tarballs and build artefacts from masquerading as packages.

Writes into the state directory:

  state.json   the diff plus first_seen per package, so staleness survives runs
  status.txt   the rendered notice, no escape codes
  status.ansi  the same notice, coloured

Nothing pending means all three are removed. The shell notice is then a file
test and a cat, which is the whole point: no eval and no network between you
and the prompt.
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone

# Past this, a pending update is called out in red and gets a day count.
STALE_DAYS = 14

# How many watched packages the notice lists before truncating.
MAX_LISTED = 5

# A trailing all-letters segment is a suffix, not part of the version. The
# store is full of derivations named after a package plus what they are to it:
# outputs (curl-8.9.1-bin, glibc-2.40-dev), vendored dependency sets
# (gh-2.99.0-go-modules, mise-2026.5.12-vendor-staging), build artefacts
# (jq-1.8.2-binlore), wrappers (firefox-141.0-unwrapped). They all carry the
# package's own version, so stripping is what makes the two sides compare.
#
# A rule rather than a list of known suffixes, because that list never ends --
# and a tail with a digit in it (1.8.2-rc1, 2.4.9-p1) is part of the version
# and stays.
ALPHA_TAIL = re.compile(r"-[A-Za-z_]+$")

# What a version is allowed to look like: every dot-separated component after
# the first has to start with a digit.
#
# This is not pedantry. The candidate side is a derivation closure, which
# includes the fetchurl derivations a package is built from, and those are
# named after the file they download -- curl-8.21.0.tar.xz.drv. That parses as
# curl 8.21.0.tar.xz, which sorts above the real 8.21.0 and hides it, so the
# notice ends up reporting "curl 8.21.0 -> 8.21.0.tar.xz". A dot followed by a
# letter is a file extension, not a version. Versions nixpkgs really uses
# (5.2p37, 1.0.2u, 0-unstable-2026-01-01, 26.05.20260903) all pass.
VERSION = re.compile(r"^[0-9][0-9A-Za-z+_~-]*(\.[0-9][0-9A-Za-z+_~-]*)*$")

STORE_PATH = re.compile(r"^/nix/store/[a-z0-9]{32}-(?P<name>.+)$")


def parse_store_path(path: str) -> tuple[str, str] | None:
    """Split a store path into (name, version), or None if it has no version."""
    match = STORE_PATH.match(path.strip())
    if not match:
        return None

    base = match.group("name").removesuffix(".drv")

    # builtins.parseDrvName: the name ends at the first dash followed by
    # something that is not a letter.
    for index, char in enumerate(base):
        if char == "-" and index + 1 < len(base) and not base[index + 1].isalpha():
            name, version = base[:index], base[index + 1:]
            break
    else:
        return None

    while True:
        stripped = ALPHA_TAIL.sub("", version)
        if stripped == version or not stripped:
            break
        version = stripped

    # Anything left that is not version-shaped is a source or an artefact, not
    # a package. Dropping it here keeps it off both sides at once.
    return (name, version) if VERSION.match(version) else None


def version_key(version: str) -> list:
    """Sort key that orders 1.10 above 1.9, unlike a plain string compare."""
    return [
        (0, int(part)) if part.isdigit() else (1, part)
        for part in re.split(r"[^0-9A-Za-z]+", version)
        if part
    ]


def newest_per_name(paths: list[str]) -> dict[str, str]:
    """Highest version seen per package name.

    A closure regularly carries several versions of the same name (two
    openssls, a bootstrap gcc). Comparing the highest of each side keeps that
    from turning into a cross product of meaningless pairs.
    """
    versions: dict[str, str] = {}
    for path in paths:
        parsed = parse_store_path(path)
        if parsed is None:
            continue
        name, version = parsed
        if name not in versions or version_key(version) > version_key(versions[name]):
            versions[name] = version
    return versions


def read_paths(path: str) -> list[str]:
    with open(path) as handle:
        return [line for line in handle.read().splitlines() if line]


def read_text(path: str) -> str:
    try:
        with open(path) as handle:
            return handle.read().strip()
    except OSError:
        return ""


def read_json(path: str, fallback):
    try:
        with open(path) as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return fallback


def is_suffix_pair(old: str, new: str) -> bool:
    """True when one version is the other plus a suffix, e.g. 1.2.3-x86_64.

    ALPHA_TAIL catches the common shape, but not one whose suffix starts with a
    digit -- a target triple (1.2.3-x86_64-unknown-linux-gnu) stops it dead.
    Nothing real ever bumps a package from X to X-something, so treat it as the
    naming artefact it is rather than reporting an update that is not one.
    """
    longer, shorter = (new, old) if len(new) > len(old) else (old, new)
    tail = longer[len(shorter):]
    return longer.startswith(shorter) and tail.startswith("-") and any(
        char.isalpha() for char in tail
    )


def days_between(then: str, now: datetime) -> int:
    try:
        seen = datetime.fromisoformat(then)
    except ValueError:
        return 0
    return max((now - seen).days, 0)


def build_rows(old: dict[str, str], new: dict[str, str], first_seen: dict[str, str],
               now: datetime) -> list[dict]:
    """Every name whose version differs, with the date it first did so."""
    stamp = now.isoformat(timespec="seconds")
    rows = []
    for name, old_version in sorted(old.items()):
        new_version = new.get(name)
        if new_version is None or new_version == old_version:
            continue
        if is_suffix_pair(old_version, new_version):
            continue
        seen = first_seen.get(name, stamp)
        rows.append({
            "name": name,
            "old": old_version,
            "new": new_version,
            "first_seen": seen,
            "pending_days": days_between(seen, now),
        })
    return rows


def render(rows: list[dict], watch: list[str], inputs: dict, color: bool) -> str:
    """The notice itself. Watched packages first, stalest first, then a count."""
    watched = [row for row in rows if row["name"] in watch]
    watched.sort(key=lambda row: (-row["pending_days"], row["name"]))
    listed = watched[:MAX_LISTED]

    def paint(text: str, code: str) -> str:
        return f"\033[{code}m{text}\033[0m" if color else text

    lines = [paint("You have pending system updates!", "1;33")]

    if listed:
        name_width = max(len(row["name"]) for row in listed)
        old_width = max(len(row["old"]) for row in listed)
        for row in listed:
            stale = row["pending_days"] >= STALE_DAYS
            name = paint(row["name"], "1;31") if stale else row["name"]
            name += " " * (name_width - len(row["name"]))
            arrow = f"{row['old']:<{old_width}} -> {row['new']}"
            suffix = f"   (pending {row['pending_days']} days)" if stale else ""
            lines.append(f" - {name}  {arrow}{suffix}")
        if len(watched) > MAX_LISTED:
            lines.append("   ...")

    # Counts what is not listed above at all. The truncated watched ones are
    # what the ... stands for, so they are not counted here twice.
    rest = len(rows) - len(watched)
    if rest > 0:
        plural = "package" if rest == 1 else "packages"
        lines.append(f" + {rest} other {plural} in the system closure")

    for name, revs in sorted(inputs.items()):
        if name == "nixpkgs" or revs["old"] == revs["new"]:
            continue
        lines.append(f" + {name} module: {revs['old'][:7]} -> {revs['new'][:7]}")

    lines += ["", " run sysupdate to update", ""]
    return "\n".join(lines)


def render_staged(path: str, reboot_hint: str, color: bool) -> str:
    header = "A system update is staged."
    match = STORE_PATH.match(path)
    return "\n".join([
        f"\033[1;33m{header}\033[0m" if color else header,
        f" {reboot_hint} to activate it.",
        f" ({match.group('name') if match else path})",
        "",
    ])


def write_status(state_dir: str, plain: str, ansi: str) -> None:
    with open(os.path.join(state_dir, "status.txt"), "w") as handle:
        handle.write(plain)
    with open(os.path.join(state_dir, "status.ansi"), "w") as handle:
        handle.write(ansi)


def clear_status(state_dir: str) -> None:
    for name in ("status.txt", "status.ansi"):
        try:
            os.unlink(os.path.join(state_dir, name))
        except FileNotFoundError:
            pass


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    # Both optional: with neither, this only settles the staged marker, which
    # is what `sysupdate` calls after staging so the notice changes at once.
    parser.add_argument("--old", help="store paths of the running closure")
    parser.add_argument("--new", help="store paths of the candidate closure")
    parser.add_argument("--watch", default="", help="comma-separated package names to name")
    parser.add_argument("--inputs", help="JSON of {input: {old, new}} flake revisions")
    parser.add_argument("--state-dir", required=True)
    parser.add_argument("--current-system", default="/run/current-system")
    parser.add_argument("--reboot-hint", default="Reboot")
    parser.add_argument("--now", help="ISO timestamp, for testing")
    args = parser.parse_args()

    now = datetime.fromisoformat(args.now) if args.now else datetime.now(timezone.utc)
    state_dir = args.state_dir
    os.makedirs(state_dir, exist_ok=True)

    # A staged update outranks a pending one: the answer is no longer "run
    # sysupdate", it is "restart". The marker clears itself once the system it
    # names is the one running.
    staged_file = os.path.join(state_dir, "staged")
    staged = read_text(staged_file)
    if staged:
        if os.path.realpath(args.current_system) != os.path.realpath(staged):
            write_status(
                state_dir,
                render_staged(staged, args.reboot_hint, color=False),
                render_staged(staged, args.reboot_hint, color=True),
            )
            return 0
        # It is the running system now, so the staged notice is answered.
        os.unlink(staged_file)
        clear_status(state_dir)

    if not (args.old and args.new):
        return 0

    old = newest_per_name(read_paths(args.old))
    new = newest_per_name(read_paths(args.new))
    inputs = read_json(args.inputs, {}) if args.inputs else {}
    watch = [name for name in args.watch.split(",") if name]

    previous = read_json(os.path.join(state_dir, "state.json"), {})
    first_seen = previous.get("first_seen", {}) if isinstance(previous, dict) else {}

    rows = build_rows(old, new, first_seen, now)
    moved = {
        name: revs for name, revs in inputs.items()
        if isinstance(revs, dict) and revs.get("old") != revs.get("new")
    }

    with open(os.path.join(state_dir, "state.json"), "w") as handle:
        json.dump({
            "checked_at": now.isoformat(timespec="seconds"),
            "packages": rows,
            "inputs": inputs,
            # Only pending packages keep a date, so a resolved update resets
            # the clock rather than counting from the first time ever.
            "first_seen": {row["name"]: row["first_seen"] for row in rows},
        }, handle, indent=2)
        handle.write("\n")

    if not rows and not moved:
        clear_status(state_dir)
        return 0

    write_status(
        state_dir,
        render(rows, watch, moved, color=False),
        render(rows, watch, moved, color=True),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
