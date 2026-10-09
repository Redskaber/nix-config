# @path: ~/projects/configs/nix-config/lib/shared/lang/validate.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: lib::shared::lang::validate — Result-typed path validation
#
# T4.1 (README roadmap: Option/Result 类型化错误处理): secret path
# construction as a Result railway over the nix-types ADT — errors are
# VALUES that carry their own diagnostics, composed with andThen, and
# thrown exactly once, at the edge where a bare string is required.
#
#   ok rel
#     └─ andThen nonEmpty      ("" is not a path)
#     └─ andThen relative      (no leading "/")
#     └─ andThen confined      (no ".." segment — stays inside the base)
#     └─ andThen wellFormed    (no empty segment: "a//b", trailing "/")
#     └─ andThen unsuffixed    (".yaml" is appended by construction)
#     └─ andThen provided      (the file exists in the tree)
#     → Ok <path> | Err <sentence with the offending input embedded>
#
# Compiler-pipeline view: the shape checks are the front end (purely
# syntactic, fail on the lexeme), the existence check is the resolution
# pass (the filesystem is the symbol table). A declared-but-missing
# secret dies at EVAL time with a "declared but not provided"
# diagnostic — not at activation time on the target machine, deep
# inside sops, where nobody is looking at your eval.
#
# The resolution pass is BOOTSTRAP-AWARE (lifecycle state machine, see
# scripts/just/secrets.just): the EMPTY state — zero blobs under the
# secrets tree, i.e. a fresh clone before `just init` / `just secret-set`
# — is the legitimate ENTRY state of the key lifecycle, not an error.
# Exactly like a compiler treats an empty symbol table as "fresh parse",
# not as an unresolved-symbol storm:
#
#   tree EMPTY (no *.yaml under the base)  → trace + Ok <path>
#       (eval proceeds; deploying now would fail at sops activation —
#       the hard failure moves to the layer that owns it)
#   tree provisioned (≥ 1 blob)            → strict per-secret check
#       (any DECLARED secret missing = "declared but not provided" Err,
#       T4.1 unchanged — once bootstrap starts, completeness is owed)
#
# Boundary discipline (railway-oriented programming): everything in
# this file returns Result. `throw` appears nowhere here — the single
# edge that needs a bare string lives in the runtime layer
# (result.unwrapOrElse (e: throw e)), so the Err diagnostic becomes
# the eval error verbatim. Same fail-early discipline as fn.sameSource,
# but the error VALUE carried its full context through the pipeline
# first — instead of a throw assembling it at one site.
#
# Layer: lib/shared (Phase 1, no pkgs dependency; needs only inputs +
#        fn — path interpolation stays single-sourced in fn.sopsFile)

{ inputs, fn, ... }:
let
  inherit (inputs.nix-types.lib) ok err result;

  # ── front end: shape checks (pure syntax, no filesystem) ──────────
  nonEmpty =
    rel:
    if rel == "" then
      err "secret path is empty — expected a repo-relative path like \"nixos/core/base/user/<name>/password\""
    else
      ok rel;

  relative =
    rel:
    if builtins.substring 0 1 rel == "/" then
      err "secret path \"${rel}\" must be repo-relative (leading \"/\") — source paths are joined from the repo root, runtime paths from constants"
    else
      ok rel;

  confined =
    rel:
    if builtins.elem ".." (builtins.split "/" rel) then
      err "secret path \"${rel}\" must not contain \"..\" segments — it has to stay inside the secrets base"
    else
      ok rel;

  wellFormed =
    rel:
    if builtins.any (s: s == "") (builtins.split "/" rel) then
      err "secret path \"${rel}\" has an empty path segment — every segment between \"/\" must be non-empty"
    else
      ok rel;

  unsuffixed =
    rel:
    if builtins.match ".*\\.yaml$" rel != null then
      err "secret path \"${rel}\" must not end in \".yaml\" — the suffix is appended by construction (fn.sopsFile)"
    else
      ok rel;

  # The pipeline itself is DATA: a list of passes folded over the
  # initial Ok. Adding a check = appending to the list; reordering the
  # front end = reordering the list. Nothing else in this file knows
  # the pass sequence exists.
  shapePasses = [
    nonEmpty
    relative
    confined
    wellFormed
    unsuffixed
  ];

  relR = rel: builtins.foldl' (acc: check: result.andThen check acc) (ok rel) shapePasses;

  # provisioned: does the tree carry at least one encrypted blob? A
  # single readDir descent, short-circuiting on the first *.yaml hit
  # (builtins.any's disjunction is lazy per element, so unexplored
  # subtrees are never forced). The base path joins through fn.sopsBase
  # — the SAME join rule fn.sopsFile uses, so the predicate walks
  # exactly the tree the resolution pass reads from (SSOT).
  anyYaml =
    dir:
    builtins.any (
      name:
      let
        ty = (builtins.readDir dir).${name};
      in
      if ty == "directory" then anyYaml (dir + "/${name}") else builtins.match ".*\\.yaml$" name != null
    ) (builtins.attrNames (builtins.readDir dir));

  provisioned =
    self: base:
    let
      dir = fn.sopsBase self base;
    in
    builtins.pathExists dir && anyYaml dir;

  # ── resolution pass (filesystem as symbol table) ───────────────────
  # self: repo root (flake self, a store path); base: secrets base dir
  # (shared.const.secrets.chipr). Ok value: the .yaml source file.
  sopsFileR =
    self: base: rel:
    result.andThen (
      r:
      let
        path = fn.sopsFile self base r;
      in
      if builtins.pathExists path then
        ok path
      else if provisioned self base then
        err "secret \"${r}\" is declared but not provided: ${path} does not exist — create it with the just lifecycle (just secret-set <alias>; state map: just secrets-guide; rotation model in docs/secrets/rotation.md)"
      else
        # EMPTY tree — pre-bootstrap entry state (fresh clone). Tolerate
        # at eval with a trace that says how to leave the state; the
        # deploy-time hard failure belongs to sops activation, not here.
        builtins.trace
          "secrets tree is EMPTY (pre-bootstrap) — declared secret \"${r}\" has no blob yet; run `just secrets-init` (or `just init <username>`) then `just secret-set-all`; deploy will fail until then"
          (ok path)
    ) (relR rel);

  # Runtime-path variant: same front end, no filesystem check (runtime
  # paths do not exist at eval time by design — sops materialises them
  # at activation).
  sopsRuntimePathR = base: rel: result.map (r: fn.sopsRuntimePath base r) (relR rel);
in
{
  inherit
    relR
    sopsFileR
    sopsRuntimePathR
    ;
}
