"""Drop the [patch] entries that Cargo.lock records as [[patch.unused]].

fetchCargoVendor vendors the packages in Cargo.lock and nothing else, so a git
patch that resolves to no package leaves cargo looking for it in a vendored
source that never got it, and the offline build fails. Removing the entries,
together with the lockfile's record of them, gives the manifest cargo would
have resolved to anyway; the build's --locked proves that.

Run from the workspace root after cargoSetupPostPatchHook has compared the
lockfile with the vendored copy.
"""

import re
import sys
import tomllib
from pathlib import Path

manifest = Path("Cargo.toml")
lockfile = Path("Cargo.lock")

lock_text = lockfile.read_text()
unused = tomllib.loads(lock_text).get("patch", {}).get("unused", [])
if not unused:
    sys.exit(0)

names = {entry["name"] for entry in unused}

# Lines are only ever removed inside [patch.*] tables, and each name has to be
# found exactly once there: a manifest laid out some other way should stop the
# build, not be half-edited.
lines = manifest.read_text().splitlines(keepends=True)
kept = []
removed = {}
in_patch = False
for line in lines:
    header = re.match(r"\s*\[([^\[\]]+)\]\s*(#.*)?$", line)
    if header:
        in_patch = header.group(1).strip().startswith("patch.")
    entry = re.match(r"\s*([A-Za-z0-9_-]+)\s*=", line) if in_patch else None
    if entry and entry.group(1) in names:
        removed[entry.group(1)] = removed.get(entry.group(1), 0) + 1
        continue
    kept.append(line)

if removed != {name: 1 for name in names}:
    sys.exit(f"strip-unused-patches: expected one [patch] line each for {sorted(names)}, found {removed}")

manifest.write_text("".join(kept))

# Cargo writes the unused records as a block after every [[package]].
start = lock_text.find("[[patch.unused]]")
if tomllib.loads(lock_text[start:]).keys() != {"patch"}:
    sys.exit("strip-unused-patches: Cargo.lock has entries after [[patch.unused]]")
lockfile.write_text(lock_text[:start].rstrip("\n") + "\n")

print(f"strip-unused-patches: removed {', '.join(sorted(names))}")
