#!/usr/bin/env python3
# ==============================================================================
# @path: ~/projects/configs/nix-config/scripts/sh/secrets-db.py
# @author: redskaber (delivered by Z.ai Code, round 27)
# @description: scripts::sh::secrets-db — the secrets registry engine
#
# The DATA-DRIVEN replacement for the hardcoded row list that used to live
# in scripts/just/secrets.just (`_secrets-registry`). Three layers, one
# direction of dependency (same discipline as the compiler pipeline the
# rest of the repo standardises on — no layer answers another layer's
# question):
#
#   CONFIG TRUTH   shared.nix + docs/tmpl/shared.nix.tmpl
#                  key -> rel-path declarations (read + structurally
#                  edited by declare-add / declare-remove)
#   REGISTRY       secrets/registry.toml
#                  alias -> key + operator UX (read + written by
#                  add / edit / remove — DATA, not code)
#   DATABASE CACHE secrets/.cache/secrets.db  (sqlite, git-ignored)
#                  materialized join of both layers + filesystem state
#                  (blob/template/plan presence, rules coverage,
#                  recipients) — rebuilt by `sync`, transparently
#                  refreshed when any input hash drifts
#
# The just verbs in scripts/just/secrets.just are thin: they validate the
# UX contract and delegate here. This file carries zero domain knowledge
# beyond the three layers above (the sops rules are read AS DATA from
# .sops.yaml — same philosophy as scripts/sh/secrets-rotate.sh).
#
# Usage (see `--help` for the full verb map):
#   sync [--force]                 rebuild the database cache
#   q rows · q row <alias>          registry queries (pipe format, compat)
#   q paths <key>                   path trio (template / rel / username)
#   q list · q show <alias>         human tables (state + dossier)
#   q declared                      declaration <-> registry drift view
#   q info · q dirs                 cache info · dirs to create (NUL-safe)
#   add <alias> <rel> [prompt] [transform]    full three-layer create
#   remove <alias>                           full three-layer delete
#   edit <alias> [prompt] [transform]        registry row update
#
# Front-end parity: `add` runs the SAME five path-shape checks lib/shared/
# lang/validate.nix runs at eval time (nonEmpty / relative / confined /
# wellFormed / unsuffixed) — a bad path is rejected at the CLI with an
# operator-readable sentence instead of dying later inside nix eval.
# ==============================================================================

import argparse
import hashlib
import os
import re
import sqlite3
import sys
import time
from pathlib import Path

if sys.version_info < (3, 11):
    sys.stderr.write(
        "Error: secrets-db.py needs python3 >= 3.11 (tomllib in stdlib); "
        f"found {sys.version_info.major}.{sys.version_info.minor}\n"
    )
    sys.exit(1)

import tomllib  # noqa: E402  (guard above ran first)

# ── anchors ───────────────────────────────────────────────────────────────────

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "secrets" / "registry.toml"
SHARED = ROOT / "shared.nix"
SHARED_TMPL = ROOT / "docs" / "tmpl" / "shared.nix.tmpl"
DOT_SOPS = ROOT / ".sops.yaml"
CHIPR = ROOT / "secrets" / "chipr"
PLAN = ROOT / "secrets" / "plan"
TMPL = ROOT / "docs" / "tmpl" / "sops"
DB = ROOT / "secrets" / ".cache" / "secrets.db"

ALIAS_RE = re.compile(r"^[a-z0-9][a-z0-9_-]*$")
USERNAME_RE = re.compile(r'^\s*username\s*=\s*"([^"]+)"', re.MULTILINE)
TRANSFORMS = ("plain", "mkpasswd")

SCHEMA = """
CREATE TABLE IF NOT EXISTS meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS registry (
    alias     TEXT PRIMARY KEY,
    key       TEXT NOT NULL UNIQUE,
    prompt    TEXT NOT NULL,
    transform TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS declaration (
    key TEXT PRIMARY KEY,
    rel TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS secret (
    alias      TEXT PRIMARY KEY,
    key        TEXT,
    rel        TEXT,
    username   TEXT,
    tmpl_abs   TEXT,
    chipr_abs  TEXT,
    plan_abs   TEXT,
    blob_state TEXT,
    tmpl_state TEXT,
    plan_state TEXT,
    domain     TEXT,
    leaf_key   TEXT,
    rule       TEXT
);
"""


# ── errors ────────────────────────────────────────────────────────────────────

class Fail(Exception):
    """Operator-facing error: the sentence, the remedy, exit 1."""


# ── layer 1: registry.toml (DATA) ──────────────────────────────────────────────

REGISTRY_HEADER = """\
# ==============================================================================
# secrets/registry.toml — the operator registry (DATA, not code)
# ==============================================================================
# One row per secret alias. This file replaces the hardcoded row list that
# used to live in scripts/just/secrets.just (`_secrets-registry`) — the
# alias table is now data, owned by the CRUD verbs:
#
#   just secrets-add <alias> <rel-path> [prompt] [transform]   # create a row
#   just secrets-edit <alias> [prompt] [transform]              # update a row
#   just secrets-remove <alias>                                 # delete a row
#   just secrets-list · secrets-show <alias> · secrets-declared  # query
#
# Row fields:
#   alias     operator handle, [a-z0-9][a-z0-9_-]*, unique
#   key       the attr path that declares this secret in shared.nix
#             (declaration identity — shared.nix maps it to the rel path;
#             paths stay single-sourced there, config is truth)
#   prompt    label shown while the value is typed (secret-set)
#   transform "plain" (store as-is) | "mkpasswd" (sha-512 hash before store)
#
# Layer map (who owns what — see scripts/just/secrets.just for the full map):
#   shared.nix      key -> rel-path declarations        (config truth)
#   this file       alias -> key + operator UX         (registry data)
#   secrets/.cache/ materialized join of both + fs    (database cache)
#
# Hand edits are allowed (it is a readable data file) — `just secrets-db`
# re-syncs the cache; the CRUD verbs normalize the layout on every write.
# Rows are kept sorted by alias for deterministic diffs.
"""


def read_registry():
    if not REGISTRY.is_file():
        raise Fail(
            f"{REGISTRY} not found — the registry is a committed data file. "
            "Restore it from git (git checkout -- secrets/registry.toml) or "
            "register secrets again with `just secrets-add`."
        )
    try:
        with open(REGISTRY, "rb") as fh:
            data = tomllib.load(fh)
    except tomllib.TOMLDecodeError as e:
        raise Fail(f"{REGISTRY} is not valid TOML: {e}")
    rows = data.get("secret", [])
    seen_alias, seen_key = set(), set()
    for row in rows:
        alias, key = row.get("alias", ""), row.get("key", "")
        if not ALIAS_RE.match(alias):
            raise Fail(f"registry row with invalid alias {alias!r} (need [a-z0-9][a-z0-9_-]*)")
        if alias in seen_alias:
            raise Fail(f"registry has duplicate alias {alias!r}")
        if key in seen_key:
            raise Fail(f"registry rows {sorted(seen_key & {key})!r} share key {key!r}")
        seen_alias.add(alias)
        seen_key.add(key)
    return rows


def write_registry(rows):
    """Normalize + write. Deterministic: header constant, rows sorted by alias."""
    rows = sorted(rows, key=lambda r: r["alias"])
    out = [REGISTRY_HEADER]
    for r in rows:
        out.append("\n[[secret]]")
        out.append(f'alias = "{r["alias"]}"')
        out.append(f'key = "{r["key"]}"')
        prompt = r["prompt"].replace('"', "'")
        out.append(f'prompt = "{prompt}"')
        out.append(f'transform = "{r["transform"]}"')
        out.append("")
    REGISTRY.write_text("\n".join(out), encoding="utf-8")


# ── layer 2: shared.nix declarations (config truth) ────────────────────────────

def parse_username():
    if not SHARED.is_file():
        raise Fail(
            f"{SHARED} not found. Run: just shared-generate <username> "
            "(the live base policy is the declaration context)."
        )
    m = USERNAME_RE.search(SHARED.read_text(encoding="utf-8"))
    if not m:
        raise Fail(f"could not parse username from {SHARED}")
    return m.group(1)


def _secrets_block(text):
    """Yield (start, end) line indexes of the `secrets = { ... };` block."""
    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if re.match(r"^\s*secrets\s*=\s*\{\s*$", line):
            start = i
            break
    if start is None:
        raise Fail('no `secrets = {` block found — expected in shared.nix / its template')
    open_indent = re.match(r"^\s*", lines[start]).group(0)
    close_re = re.compile(r"^" + open_indent + r"\};\s*$")
    for j in range(start + 1, len(lines)):
        if close_re.match(lines[j]):
            return lines, start, j
    raise Fail("`secrets = {` block is never closed (`};` at matching indent not found)")


DECL_RE_TMPL = r"^(?P<indent>\s+)(?P<key>[a-zA-Z0-9._-]+)\s*=\s*(?P<rest>.*)$"


def parse_declarations(text):
    """key -> rel for every string-valued attr in the secrets block
    (list-valued entries like sshKeyPaths are skipped — they are not
    secret path declarations). Values may wrap to the next line (nixfmt
    wraps long assignments); the parser accepts both shapes, mirroring
    the perl slurp the previous implementation used."""
    lines, start, end = _secrets_block(text)
    decls = {}
    i = start + 1
    entry_re = re.compile(DECL_RE_TMPL)
    while i < end:
        m = entry_re.match(lines[i])
        if not m:
            i += 1
            continue
        key, rest = m.group("key"), m.group("rest").strip()
        if rest.startswith("[") or rest.startswith("{"):
            i += 1
            continue
        if rest.startswith('"'):
            val = rest[1 : rest.find('"', 1)] if '"' in rest[1:] else ""
        elif rest in ("", "="):
            # wrapped: value quoted on the next line (nixfmt wraps long
            # assignments — see the postgresql row in shared.nix)
            nxt = lines[i + 1].strip() if i + 1 < end else ""
            m2 = re.match(r'^"([^"]*)"', nxt)
            if not m2:
                i += 1
                continue
            val = m2.group(1)
        else:
            i += 1
            continue
        if "." in key:  # dotted attr paths are the secret declarations
            decls[key] = val
        i += 1
    return decls


def declare_add(key, rel, both=True):
    """Structurally insert `key = "rel";` into the secrets block of
    shared.nix (and its template — they are kept byte-equivalent modulo
    the username substitution, see `just shared-roundtrip`)."""
    targets = [SHARED] + ([SHARED_TMPL] if both else [])
    for path in targets:
        text = path.read_text(encoding="utf-8")
        decls = parse_declarations(text)
        if key in decls:
            continue  # idempotent per-file
        lines, start, end = _secrets_block(text)
        indent = re.match(r"^\s+", lines[start + 1]).group(0) if start + 1 < end else "    "
        entry = f"{indent}{key} = \"{rel}\";"
        if len(entry) > 99:
            # nixfmt's wrap shape (continuation indent = entry indent + 2)
            entry = f"{indent}{key} =\n{indent}  \"{rel}\";"
        lines.insert(end, entry)
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def declare_remove(key, both=True):
    """Remove the (possibly wrapped) declaration of `key` from the secrets
    block of shared.nix (and its template)."""
    targets = [SHARED] + ([SHARED_TMPL] if both else [])
    entry_re = re.compile(
        r"^\s+" + re.escape(key) + r'\s*=\s*(?:"[^"]*";|=\s*$|\s*$)'
    )
    cont_re = re.compile(r'^\s+"[^"]*";')
    removed_any = False
    for path in targets:
        text = path.read_text(encoding="utf-8")
        lines, start, end = _secrets_block(text)
        out, i, removed = [], start + 1, False
        while i < end:
            m = entry_re.match(lines[i])
            if m:
                # value wrapped onto the next line?
                if not lines[i].rstrip().endswith(";") and i + 1 < end and cont_re.match(lines[i + 1]):
                    i += 2
                else:
                    i += 1
                removed = True
                continue
            out.append(lines[i])
            i += 1
        if removed:
            body = lines[: start + 1] + out + lines[end:]
            path.write_text("\n".join(body) + "\n", encoding="utf-8")
            removed_any = True
    return removed_any


# ── layer 2b: path shape (front-end parity with lib/shared/lang/validate.nix) ──

def check_rel(rel):
    if rel == "":
        raise Fail('secret path is empty — expected a repo-relative path like "nixos/core/base/user/<name>/password"')
    if rel.startswith("/"):
        raise Fail(f'secret path "{rel}" must be repo-relative (leading "/")')
    segs = rel.split("/")
    if ".." in segs:
        raise Fail(f'secret path "{rel}" must not contain ".." segments — it has to stay inside the secrets base')
    if any(s == "" for s in segs):
        raise Fail(f'secret path "{rel}" has an empty path segment — every segment between "/" must be non-empty')
    if rel.endswith(".yaml"):
        raise Fail(f'secret path "{rel}" must not end in ".yaml" — the suffix is appended by construction')
    return rel


# ── layer 3: sops rules as data (coverage + domain) ────────────────────────────

def read_rules():
    """creation_rules from .sops.yaml AS DATA — [(path_regex, …)].
    Returns [] when the rules are absent (EMPTY lifecycle state —
    `add` refuses then: a blob without a rule is a plaintext risk).
    First-match-wins dispatch is sops' own contract; no yaml parser is
    needed to extract the ordered path_regex list."""
    if not DOT_SOPS.is_file():
        return []
    rules = []
    for line in DOT_SOPS.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\s*-\s*path_regex:\s*(\S+)\s*$", line)
        if m:
            rules.append({"regex": m.group(1).strip("'\"")})
    return rules


def rule_for(rel):
    """First creation_rule whose path_regex matches `secrets/chipr/<rel>.yaml`
    (sops dispatches first-match-wins on the full relative path)."""
    target = f"secrets/chipr/{rel}.yaml"
    for rule in read_rules():
        try:
            if re.search(rule["regex"], target):
                return rule
        except re.error:
            continue
    return None


def domain_of(rel):
    return "srv" if re.match(r"^nixos/core/srv/", rel) else "base"


# ── templates ────────────────────────────────────────────────────────────────

def template_rel(rel):
    """${username} -> __USERNAME__ (the canonical substitution rule —
    position-agnostic, segments and affixes alike)."""
    return rel.replace("${username}", "__USERNAME__")


def template_abs(rel):
    return TMPL / f"{template_rel(rel)}.yaml"


def write_template(rel):
    """Nested-YAML skeleton mirroring the path segments, leaf key = last
    segment, placeholder __SECRET_VALUE__ — the same convention the
    committed templates follow (see the sops-nix leaf-key rule in
    scripts/just/secrets.just's header)."""
    segs = template_rel(rel).split("/")
    lines = []
    for i, seg in enumerate(segs):
        pad = "  " * i
        if i == len(segs) - 1:
            lines.append(f'{pad}{seg}: "__SECRET_VALUE__"')
        else:
            lines.append(f"{pad}{seg}:")
    path = template_abs(rel)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


# ── layer 4: the database cache (sqlite) ─────────────────────────────────────

def _tree_fingerprint(root_path):
    if not root_path.is_dir():
        return ""
    acc = []
    for p in sorted(root_path.rglob("*")):
        if p.is_file():
            st = p.stat()
            acc.append(f"{p.relative_to(ROOT)}:{st.st_size}:{int(st.st_mtime)}")
    return "\n".join(acc)


def inputs_fingerprint():
    parts = []
    for p in (REGISTRY, SHARED, DOT_SOPS):
        parts.append(f"{p}:{p.stat().st_size}:{int(p.stat().st_mtime)}" if p.is_file() else f"{p}:-")
    for tree in (CHIPR, PLAN, TMPL):
        parts.append(_tree_fingerprint(tree))
    return hashlib.sha256("\n".join(parts).encode()).hexdigest()


def sync(force=False):
    rows = read_registry()
    username = parse_username()
    shared_text = SHARED.read_text(encoding="utf-8")
    decls = parse_declarations(shared_text)

    DB.parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(DB)
    con.executescript("DROP TABLE IF EXISTS registry; DROP TABLE IF EXISTS declaration; DROP TABLE IF EXISTS secret; DROP TABLE IF EXISTS meta;")
    con.executescript(SCHEMA)
    with con:
        con.execute(
            "INSERT INTO meta VALUES ('schema_version', '1')"
        )
        con.execute("INSERT INTO meta VALUES ('username', ?)", (username,))
        con.execute("INSERT INTO meta VALUES ('built_at', ?)", (time.strftime("%Y-%m-%dT%H:%M:%S"),))
        con.execute("INSERT INTO meta VALUES ('inputs_fingerprint', ?)", (inputs_fingerprint(),))
        for r in rows:
            con.execute(
                "INSERT INTO registry VALUES (?,?,?,?)",
                (r["alias"], r["key"], r.get("prompt", ""), r.get("transform", "plain")),
            )
        for key, rel in decls.items():
            con.execute("INSERT INTO declaration VALUES (?,?)", (key, rel))
        for r in rows:
            key = r["key"]
            rel = decls.get(key)
            # filesystem truth lives under the RESOLVED username; the
            # declaration keeps the ${username} placeholder (canonical
            # substitution rule — single global literal replacement)
            resolved = rel.replace("${username}", username) if rel else None
            t_abs = template_abs(rel) if rel else None
            blob = CHIPR / f"{resolved}.yaml" if resolved else None
            plan = PLAN / f"{resolved}.yaml" if resolved else None
            rule = rule_for(rel) if rel else None
            con.execute(
                "INSERT INTO secret VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (
                    r["alias"], key, rel, username,
                    str(t_abs) if t_abs else None,
                    str(blob) if blob else None,
                    str(plan) if plan else None,
                    ("set" if blob and blob.is_file() else "missing") if rel else "no-declaration",
                    ("set" if t_abs and t_abs.is_file() else "missing") if rel else "-",
                    ("set" if plan and plan.is_file() else "missing") if rel else "-",
                    domain_of(rel) if rel else None,
                    rel.rsplit("/", 1)[-1] if rel else None,
                    rule["regex"] if rule else None,
                ),
            )
    con.close()


def ensure_fresh():
    """The cache contract: every query transparently rebuilds when an input
    drifts (registry / shared.nix / rules / any tree mtime). One hash, one
    stat walk — milliseconds on this repo's scale."""
    if not DB.is_file():
        sync()
        return
    con = sqlite3.connect(DB)
    try:
        row = con.execute("SELECT value FROM meta WHERE key='inputs_fingerprint'").fetchone()
    except sqlite3.OperationalError:
        row = None
    con.close()
    if row is None or row[0] != inputs_fingerprint():
        sync()


def db():
    ensure_fresh()
    con = sqlite3.connect(DB)
    con.row_factory = sqlite3.Row
    return con


# ── query emitters ────────────────────────────────────────────────────────────

def q_rows():
    con = db()
    for r in con.execute("SELECT * FROM registry ORDER BY alias"):
        print(f"{r['alias']}|{r['key']}|{r['prompt']}|{r['transform']}")
    con.close()


def q_row(alias):
    con = db()
    r = con.execute("SELECT * FROM registry WHERE alias=?", (alias,)).fetchone()
    if r is None:
        known = " ".join(x[0] for x in con.execute("SELECT alias FROM registry ORDER BY alias"))
        con.close()
        raise Fail(
            f"unknown secret alias '{alias}'.\n"
            f"  known: {known}\n"
            "  map  : just secrets-list"
        )
    print(f"{r['alias']}|{r['key']}|{r['prompt']}|{r['transform']}")
    con.close()


def q_paths(key):
    """Compat trio with the old `_secrets-paths`: template abs path
    (placeholder form), resolved rel path (real username), username."""
    con = db()
    d = con.execute("SELECT rel FROM declaration WHERE key=?", (key,)).fetchone()
    u = con.execute("SELECT value FROM meta WHERE key='username'").fetchone()
    con.close()
    if d is None or u is None:
        raise Fail(
            f"key '{key}' not found in {SHARED} — declare it first "
            "(just secrets-add, or edit the secrets block by hand)."
        )
    rel, username = d["rel"], u["value"]
    print(f"{TMPL / (template_rel(rel) + '.yaml')}")
    print(rel.replace("${username}", username))
    print(username)


def q_list():
    con = db()
    username = con.execute("SELECT value FROM meta WHERE key='username'").fetchone()["value"]
    print(f"{'ALIAS':<12} {'DOM':<5} {'STATE':<8} {'SECRET':<40} DECLARED")
    for s in con.execute("SELECT * FROM secret ORDER BY alias"):
        rel = (s["rel"] or "").replace("${username}", username) or "(no declaration)"
        print(
            f"{s['alias']:<12} {s['domain'] or '-':<5} {s['blob_state']:<8} "
            f"{rel:<40} {'yes' if s['rel'] else 'NO'}"
        )
    con.close()


def q_show(alias):
    con = db()
    s = con.execute("SELECT * FROM secret WHERE alias=?", (alias,)).fetchone()
    reg = con.execute("SELECT * FROM registry WHERE alias=?", (alias,)).fetchone()
    if s is None or reg is None:
        known = " ".join(x[0] for x in con.execute("SELECT alias FROM registry ORDER BY alias"))
        con.close()
        raise Fail(f"unknown secret alias '{alias}'.\n  known: {known}")
    u = con.execute("SELECT value FROM meta WHERE key='username'").fetchone()["value"]
    con.close()
    rel = s["rel"]
    print(f"alias      : {reg['alias']}")
    print(f"key        : {reg['key']}")
    print(f"prompt     : {reg['prompt']}")
    print(f"transform  : {reg['transform']}")
    print(f"domain     : {s['domain'] or '-'}")
    if rel:
        print(f"declared   : {rel}")
        print(f"  resolved: {rel.replace('${username}', u)}")
        print(f"leaf key   : {s['leaf_key']}  (sops-nix walks the YAML to it)")
        print(f"sops rule  : {s['rule'] or 'NONE — a blob here would be a plaintext risk'}")
        for label, path, state in (
            ("template  ", s["tmpl_abs"], s["tmpl_state"]),
            ("blob      ", s["chipr_abs"], s["blob_state"]),
            ("plan      ", s["plan_abs"], s["plan_state"]),
        ):
            if path is None:
                print(f"{label.strip():<10}: - (no declaration)")
                continue
            extra = ""
            if state == "set":
                st = Path(path).stat()
                extra = f"  ({st.st_size} bytes, {time.strftime('%Y-%m-%d %H:%M', time.localtime(st.st_mtime))})"
                if "blob" in label:
                    text = Path(path).read_text(encoding="utf-8", errors="replace")
                    recips = re.findall(r"recipient:\s*(age1[0-9a-z]+)", text)
                    extra += f"  recipients: {', '.join(recips) if recips else '(unreadable)'}"
            print(f"{label.strip():<10}: {state:<8}{extra}\n             {path}")
    else:
        print("declared   : MISSING — run `just secrets-add`-style repair or declare in shared.nix")


def q_declared():
    """The drift view: shared.nix declarations (config truth) x registry
    rows x blob state. Four states are legible at a glance —
    declared+registered (healthy), declared-no-row (no just verb covers
    it), row-no-declaration (registry dangling), blob missing."""
    con = db()
    username = con.execute("SELECT value FROM meta WHERE key='username'").fetchone()["value"]
    decls = {r["key"]: r["rel"] for r in con.execute("SELECT key, rel FROM declaration")}
    reg = {r["key"]: r["alias"] for r in con.execute("SELECT key, alias FROM registry")}
    con.close()
    print(f"{'DECLARATION (shared.nix)':<44} {'ALIAS':<12} BLOB")
    for key in sorted(decls):
        alias = reg.get(key, "-")
        rel = decls[key].replace("${username}", username)
        blob = CHIPR / f"{rel}.yaml"
        state = "set" if blob.is_file() else "MISSING"
        note = "" if key in reg else "  <- no registry row (no just verb covers it)"
        print(f"{key:<44} {alias:<12} {state}{note}")
    for key, alias in sorted(reg.items()):
        if key not in decls:
            print(f"{key:<44} {alias:<12} -       <- registry row without a declaration")
    print()
    print(f"declarations: {len(decls)} · registry rows: {len(reg)} · blob set: "
          f"{sum(1 for k in decls if (CHIPR / (decls[k].replace('${username}', username) + '.yaml')).is_file())}")


def q_dirs():
    """Every directory the declared secrets need (plan + chipr parents),
    NUL-separated — the mkdir consumer stays injection-safe."""
    con = db()
    username = con.execute("SELECT value FROM meta WHERE key='username'").fetchone()["value"]
    dirs = set()
    for d in con.execute("SELECT rel FROM declaration"):
        rel = d["rel"].replace("${username}", username)
        dirs.add(str((PLAN / rel).parent))
        dirs.add(str((CHIPR / rel).parent))
    con.close()
    sys.stdout.write("\0".join(sorted(dirs)) + "\0")


def q_info():
    con = db()
    meta = {k: v for k, v in con.execute("SELECT key, value FROM meta")}
    counts = {
        "registry rows": con.execute("SELECT COUNT(*) FROM registry").fetchone()[0],
        "declarations": con.execute("SELECT COUNT(*) FROM declaration").fetchone()[0],
        "joined secrets": con.execute("SELECT COUNT(*) FROM secret").fetchone()[0],
        "blobs set": con.execute("SELECT COUNT(*) FROM secret WHERE blob_state='set'").fetchone()[0],
        "blobs missing": con.execute("SELECT COUNT(*) FROM secret WHERE blob_state='missing'").fetchone()[0],
    }
    con.close()
    print(f"database   : {DB}")
    print(f"built at   : {meta.get('built_at', '?')}")
    print(f"fingerprint: {meta.get('inputs_fingerprint', '?')[:16]}…")
    for k, v in counts.items():
        print(f"{k:<15}: {v}")


# ── CRUD ──────────────────────────────────────────────────────────────────────

def cmd_add(alias, rel, prompt, transform):
    if not ALIAS_RE.match(alias):
        raise Fail(f"alias must match [a-z0-9][a-z0-9_-]* (got '{alias}')")
    check_rel(rel)
    if transform not in TRANSFORMS:
        raise Fail(f"transform must be one of {TRANSFORMS} (got '{transform}')")
    if prompt and "|" in prompt:
        raise Fail('prompt must not contain "|" (it crosses the pipe-format field boundary)')
    rows = read_registry()
    for r in rows:
        if r["alias"] == alias:
            raise Fail(f"alias '{alias}' is already registered for key '{r['key']}' — use `just secrets-edit {alias}` or pick another alias")
    username = parse_username()
    shared_text = SHARED.read_text(encoding="utf-8")
    decls = parse_declarations(shared_text)
    # canonical key derivation: path dots, pure ${username} segments
    # skipped (the legacy rows' convention — e.g. path nixos/core/base/
    # user/${username}/password carries key nixos.core.base.user.password).
    # An affix like redis-${username} cannot canonically map to a static
    # attr name; those rare rows are hand-declared (registry accepts them
    # as data — only `add` derivation refuses).
    segs = check_rel(rel).split("/")
    if any("${username}" in s and s != "${username}" for s in segs):
        raise Fail(
            f'path "{rel}" embeds the username as an affix — the canonical key '
            "derivation cannot map it to a static attr name. Declare such a "
            "secret by hand: registry.toml row + shared.nix declaration with a "
            "key you choose (see the redis row for the pattern)."
        )
    key = ".".join(s for s in segs if s != "${username}")
    if key in decls and any(r["key"] == key for r in rows):
        raise Fail(f"key '{key}' is already declared + registered — this secret exists")
    if key in decls:
        raise Fail(
            f"key '{key}' is already declared in shared.nix but not registered — "
            "register it under an alias whose key matches, or remove the stray "
            "declaration first (see `just secrets-declared` for the drift view)"
        )
    if "${username}" in rel:
        # keep the substitution honest: the live declaration interpolates it
        pass
    rule = rule_for(rel)
    if rule is None:
        raise Fail(
            f"no .sops.yaml creation_rule covers secrets/chipr/{rel}.yaml — "
            "a blob there would be a plaintext risk (secrets-verify class). "
            "Add a rule first (docs/tmpl/sops/sops-rules.yaml.tmpl + "
            "just secrets-verify), then retry."
        )
    if not prompt:
        prompt = f"{alias} secret"
    # 1. registry row (DATA)
    rows.append({"alias": alias, "key": key, "prompt": prompt, "transform": transform})
    write_registry(rows)
    # 2. template skeleton (skip when one already exists — it may carry
    #    hand-authored structure beyond the skeleton)
    tpath = template_abs(rel)
    if tpath.is_file():
        print(f"template   : kept existing {tpath}")
    else:
        write_template(rel)
        print(f"template   : {tpath}")
    # 3. declaration (config truth, live + template kept equivalent)
    declare_add(key, rel)
    print(f"declared   : {key} = \"{rel}\"  (shared.nix + docs/tmpl/shared.nix.tmpl)")
    # 4. database cache
    sync()
    print(f"registered : alias '{alias}' -> {key}  (domain {domain_of(rel)}, rule {rule['regex']})")
    print()
    print("Next:")
    print(f"  just secret-set {alias}          # type the value (encrypted on entry)")
    if not (CHIPR / f"{rel.replace('${username}', username)}.yaml").is_file():
        print(f"  just nix fmt  (or nixfmt)        # the declaration line lands nixfmt-clean; verify once")
    print("  just secrets-verify               # hierarchy audit stays green")


def cmd_remove(alias):
    rows = read_registry()
    row = next((r for r in rows if r["alias"] == alias), None)
    if row is None:
        raise Fail(f"unknown secret alias '{alias}' (see `just secrets-list`)")
    con = db()
    s = con.execute("SELECT * FROM secret WHERE alias=?", (alias,)).fetchone()
    con.close()
    if s is not None and s["blob_state"] == "set":
        raise Fail(
            f"refusing: the encrypted blob still exists ({s['chipr_abs']}).\n"
            f"  Destroy it first: just secret-remove {alias}\n"
            "  (then re-run this command to retire the declaration)."
        )
    key = row["key"]
    rel = None
    if s is not None and s["rel"]:
        rel = s["rel"]
    # 1. registry row
    rows = [r for r in rows if r["alias"] != alias]
    write_registry(rows)
    print(f"unregistered : alias '{alias}' (registry.toml row removed)")
    # 2. template skeleton (only the generated skeleton shape — a
    #    hand-evolved template is left for human review)
    if rel:
        tpath = template_abs(rel)
        if tpath.is_file():
            text = tpath.read_text(encoding="utf-8")
            if "__SECRET_VALUE__" in text:
                tpath.unlink()
                print(f"template     : {tpath} (skeleton removed)")
            else:
                print(f"template     : KEPT {tpath} (no placeholder — hand-evolved, review manually)")
    # 3. declaration (config truth)
    if declare_remove(key):
        print(f"undeclared   : {key} = \"{rel}\" (shared.nix + docs/tmpl/shared.nix.tmpl)")
    else:
        print(f"undeclared   : {key} had no declaration line (already clean)")
    # 4. database cache
    sync()
    print("database     : re-synced")
    print("Note: the sops blob tree is untouched by this verb — it was empty or you removed it first.")


def cmd_edit(alias, prompt, transform):
    # Empty string (just-side default "") and None (absent) both mean
    # "keep the current value" — the doc contract of `just secrets-edit`.
    if transform and transform not in TRANSFORMS:
        raise Fail(f"transform must be one of {TRANSFORMS} (got '{transform}')")
    if prompt and "|" in prompt:
        raise Fail('prompt must not contain "|" (pipe-format field boundary)')
    rows = read_registry()
    row = next((r for r in rows if r["alias"] == alias), None)
    if row is None:
        raise Fail(f"unknown secret alias '{alias}' (see `just secrets-list`)")
    if prompt:
        row["prompt"] = prompt
    if transform:
        row["transform"] = transform
    write_registry(rows)
    sync()
    print(f"updated : {alias} -> prompt '{row['prompt']}', transform '{row['transform']}'")
    if row["transform"] == "mkpasswd":
        print("note    : transform applies at the NEXT secret-set (values in blobs are not re-hashed)")


# ── main ──────────────────────────────────────────────────────────────────────

def main(argv):
    ap = argparse.ArgumentParser(
        prog="secrets-db.py",
        description="the secrets registry engine: data-driven registry + sqlite cache + CRUD",
    )
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("sync", help="rebuild the database cache (registry x declarations x filesystem)")
    p.add_argument("--force", action="store_true")

    q = sub.add_parser("q", help="query the database cache (transparently refreshed)")
    q_sub = q.add_subparsers(dest="verb", required=True)
    q_sub.add_parser("rows", help="all registry rows, pipe format (alias|key|prompt|transform)")
    for name, help_ in (("row", "one registry row by alias"), ("show", "full dossier for one alias")):
        sp = q_sub.add_parser(name, help=help_)
        sp.add_argument("alias")
    sp = q_sub.add_parser("paths", help="template abs / resolved rel / username trio for a key")
    sp.add_argument("key")
    q_sub.add_parser("list", help="alias x domain x state table")
    q_sub.add_parser("declared", help="declaration <-> registry drift view")
    q_sub.add_parser("info", help="cache state (built_at, fingerprint, counts)")
    q_sub.add_parser("dirs", help="NUL-separated dirs the declarations need")

    p = sub.add_parser("add", help="register a secret: registry row + template + declaration")
    p.add_argument("alias")
    p.add_argument("rel", help="repo-relative path under secrets/chipr (no .yaml)")
    p.add_argument("prompt", nargs="?", default="")
    p.add_argument("transform", nargs="?", default="plain")

    p = sub.add_parser("remove", help="retire a secret: registry row + template + declaration")
    p.add_argument("alias")

    p = sub.add_parser("edit", help="update a registry row (prompt / transform)")
    p.add_argument("alias")
    p.add_argument("prompt", nargs="?", default="")
    p.add_argument("transform", nargs="?", default=None)

    args = ap.parse_args(argv)
    try:
        if args.cmd == "sync":
            sync(force=args.force)
            q_info()
        elif args.cmd == "q":
            if args.verb in ("row", "show"):
                (q_row if args.verb == "row" else q_show)(args.alias)
            elif args.verb == "paths":
                q_paths(args.key)
            else:
                {
                    "rows": q_rows,
                    "list": q_list,
                    "declared": q_declared,
                    "info": q_info,
                    "dirs": q_dirs,
                }[args.verb]()
        elif args.cmd == "add":
            cmd_add(args.alias, args.rel, args.prompt, args.transform)
        elif args.cmd == "remove":
            cmd_remove(args.alias)
        elif args.cmd == "edit":
            cmd_edit(args.alias, args.prompt, args.transform)
    except Fail as e:
        sys.stderr.write(f"Error: {e}\n")
        sys.exit(1)


if __name__ == "__main__":
    main(sys.argv[1:])
