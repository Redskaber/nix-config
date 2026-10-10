#!/usr/bin/env bash
# @path: ~/projects/configs/nix-config/scripts/sh/test-count.sh
# @author: redskaber
# @datetime: 2026-10-08
# @description: scripts::sh::test-count — local quick counter for test counts
#
# T8.1: the machine-enforced authority is now tests/docs-ssot.nix (a
# checks member — README/test-matrix count anchors asserted against
# live evaluation at build time, red CI on drift). This script stays
# as the zero-eval local quick lookup for humans; its output must
# agree with the check's live facts (they count the same tree).
#
# README numbers and the CI summary table align with this script.
#
# Counting semantics mirror CI discovery (attrName prefixes):
#   tests/default.nix      registry planes 0-4  (runner: nixosTest — the
#                          runTest/nmtTest helpers were deadnix-cleaned,
#                          plane 5 wires its own harness via ./nmt)
#   tests/nmt/default.nix   buildTest lines    (Plane 5, nmt_ prefix)
#   tests/pre-commit.nix    hooks block       (enabled hooks, inside the
#                          one pre-commit-check derivation)

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

planes="$(python3 - << 'PY'
import re
s = open("tests/default.nix", encoding="utf-8").read()
blocks = re.split(r"(plane\d_\w+)\s*=\s*\{", s)
total = 0
for i in range(1, len(blocks), 2):
    name, body = blocks[i], blocks[i + 1].split("};")[0]
    n = len(re.findall(r"^\s{4}[a-z][a-zA-Z0-9_]+\s*=\s*nixosTest", body, re.M))
    total += n
    print(f"  {name}: {n}")
print(f"  vm_subtotal: {total}")
PY
)"
nmt="$(grep -c '= buildTest ./' tests/nmt/default.nix)"
hooks="$(python3 - << 'PY'
import re
# T5.1 moved the git-hooks block out of flake.nix into its own module;
# the counter follows the move (this was the 2026-10 AttributeError:
# flake.nix no longer contains a `hooks = {` block to parse).
s = open("tests/pre-commit.nix", encoding="utf-8").read()
m = re.search(r"hooks\s*=\s*\{", s)
i = s.index("{", m.start()); depth = 0
for j in range(i, len(s)):
    if s[j] == "{": depth += 1
    elif s[j] == "}":
        depth -= 1
        if depth == 0: break
body = s[i:j]
keys = set(re.findall(r"^\s+([a-z0-9][a-z0-9.-]*)\s*(?:\.enable)?\s*=", body, re.M)) - {"enable", "excludes", "src", "settings"}
print(len(keys))
PY
)"

echo "Test counts (local quick lookup — machine-enforced authority: tests/docs-ssot.nix):"
echo "$planes"
echo "  plane5_nmt: ${nmt}"
echo "  pre_commit_hooks: ${hooks} (inside 1 pre-commit-check derivation)"
python3 -c "
vm=$(echo "$planes" | awk -F': ' '/vm_subtotal/{print $2}')
print(f'  tests_total: {vm}+$nmt = {vm+$nmt}')
print(f'  checks_total: {vm}+$nmt+2 = {vm+$nmt+2}')  # + pre-commit-check + docs-ssot-check drvs
"
