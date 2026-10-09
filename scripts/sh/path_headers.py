#!/usr/bin/env python3
# @path: ~/projects/configs/nix-config/scripts/sh/path_headers.py
# @author: redskaber
# @datetime: 2026-10-08
# @description: scripts::sh::path_headers — @path header consistency guard
#
# Every .nix file carries a `# @path: ~/projects/configs/nix-config/<rel>`
# header. Files move; headers rot. This script keeps them honest.
#
# Usage:
#   path_headers.py --check   exit 1 on drift (CI / pre-commit mode)
#   path_headers.py --fix     rewrite headers in place
#
# Skips generated artifacts (shared.nix) whose header intentionally points
# at their template source.

import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SKIP = {"shared.nix"}          # generated from docs/tmpl/shared.nix.tmpl
PAT = re.compile(r"^(# @path: ~/projects/configs/nix-config/)[^\n]*$", re.M)
FULL = "# @path: ~/projects/configs/nix-config/{rel}\n# @author: redskaber\n# @datetime: {today}\n# @description: {mod} \n"

def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "--check"
    drift = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in (".git", "result")]
        for f in sorted(filenames):
            if not f.endswith(".nix") or f in SKIP:
                continue
            p = os.path.join(dirpath, f)
            rel = os.path.relpath(p, ROOT)
            want = f"# @path: ~/projects/configs/nix-config/{rel}"
            src = open(p, encoding="utf-8").read()
            m = re.search(r"^# @path: .*$", src, re.M)
            if m:
                if m.group(0) != want:
                    drift.append((p, "stale", m.group(0), want))
                    if mode == "--fix":
                        src = src[:m.start()] + want + src[m.end():]
            else:
                mod = "::".join(rel[:-4].split("/"))
                head = FULL.format(rel=rel, today="2026-10-08", mod=mod)
                drift.append((p, "missing", "", want))
                if mode == "--fix":
                    src = head + "\n" + src.lstrip("\n")
            if mode == "--fix" and any(d[0] == p for d in drift):
                open(p, "w", encoding="utf-8").write(src)
    for p, kind, old, want in drift:
        print(f"{'FIXED' if mode=='--fix' else 'DRIFT'} {kind:7s} {os.path.relpath(p, ROOT)}")
        if kind == "stale":
            print(f"      - {old}")
            print(f"      + {want}")
    if drift and mode == "--check":
        sys.exit(1)
    print(f"{'fixed' if mode=='--fix' else 'checked'}: {len(drift)} drift(s)")

if __name__ == "__main__":
    main()
