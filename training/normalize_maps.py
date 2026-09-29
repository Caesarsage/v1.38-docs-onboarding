#!/usr/bin/env python3
"""Rewrite krel map files into the v1.37 layout.

Keeps each map's text and any fields set in the map, fills sigs/kinds/areas
from release-notes-draft.json, and blanks pr_body.
"""
import json
import sys
from pathlib import Path

import yaml

rn = Path(sys.argv[1])
hide = {int(p) for p in sys.argv[2:]}
draft = json.loads((rn / "release-notes-draft.json").read_text())


def block(s):
    return "|-\n" + "".join(f"    {line}\n" if line else "\n" for line in s.splitlines())


def seq(key, items):
    return f"  {key}:\n" + "".join(f"  - {i}\n" for i in items)


for path in sorted((rn / "maps").glob("pr-*-map.yaml")):
    m = yaml.safe_load(path.read_text())
    pr = m["pr"]
    note = m.get("releasenote") or {}
    entry = draft.get(str(pr), {})

    out = f'pr: {pr}\npr_body: ""\nreleasenote:\n  text: {block(note["text"].strip())}'
    dnp = True if pr in hide else note.get("do_not_publish")
    if dnp is not None:
        out += f"  do_not_publish: {str(dnp).lower()}\n"
    for key in ("sigs", "kinds", "areas"):
        items = note.get(key) or entry.get(key) or []
        if items:
            out += seq(key, items)
    path.write_text(out)
