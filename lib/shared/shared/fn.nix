# @path: ~/projects/configs/nix-config/lib/shared/shared/fn.nix
# @author: redskaber
# @datetime: 2026-04-23
# @description: lib::shared::shared::fn
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
#
# Pure utility functions for the shared layer.
# All functions here are stateless and do not depend on pkgs or inputs.
# They operate only on the shared attrset values (enums, strings, lists).
#
# Design: dependency-free — importable at schema stage (phase 1) without pkgs.
#
# T4.0 (dispatch-layer convergence): the isNixOS/isLinux/isMacOS/isWSL
# tag-comparison predicates are GONE — deliberately. Platform semantics
# now live in exactly one place, the platform dispatch table
# (enum.nix: caps vectors + strategy payloads). Consumers read resolved
# facts (shared.caps.*, shared.platform.value.*) instead of re-deriving
# "what does this platform mean" at every call site — the compiler-pipeline
# rule: later passes query the target description, they never re-lex it.

{
  ...
}:
let
  # Derive the home directory path for a given platform and username.
  # The prefix is platform payload data (enum.nix platform table:
  # home-prefix), so this is pure interpolation — zero branching. Adding
  # a platform row with a different convention needs no change here.
  # Usage: fn.homeDir shared.platform shared.user.username
  homeDir = platform: username: "${platform.value.home-prefix}/${username}";

  # Base directory of the encrypted secrets tree — the sopsFile join with
  # the rel/suffix parts stripped. Single-sourced so the resolution pass's
  # provisioned-predicate (validate.nix) walks exactly the tree fn.sopsFile
  # reads from: one join rule, two consumers.
  # Usage: fn.sopsBase self secretBase
  sopsBase = self: secretBase: "${self}/${secretBase}";

  # Build a sops secret file path from the secrets attrset value.
  # Usage: fn.sopsFile self secretBase secretRel
  #   secretRel: e.g. "nixos/core/base/user/kilig/password"
  sopsFile =
    self: secretBase: secretRel:
    "${sopsBase self secretBase}/${secretRel}.yaml";

  # Build a sops secret file path for runtime path use
  sopsRuntimePath = rbase: rpath: "${rbase}/${rpath}";

  # ── T2.6: dual-source governance ─────────────────────────────
  # Package-set fingerprint: identifies the nixpkgs instance a scope was
  # imported from (stable "26.05" vs unstable "26.11pre…" etc.). Pure —
  # works on any set that carries lib.trivial.version (module-system pkgs,
  # shared.pkgs, shared.upkgs, or test marker sets).
  pkgsFingerprint = scope: scope.lib.trivial.version;

  # Eval-time same-source contract guard (the 995d8c9 incident class).
  #   contract — human-readable name for the failing site
  #   daemon  — package set the daemon side is assembled from
  #   actual  — package set the addons side is drawn from
  # Returns `actual` when both fingerprint to ONE nixpkgs instance and
  # throws otherwise — mixed-source configurations die at eval time,
  # not at the login screen.
  sameSource =
    contract: daemon: actual:
    if pkgsFingerprint daemon == pkgsFingerprint actual then
      actual
    else
      throw "same-source contract violated (${contract}): daemon scope is nixpkgs-${pkgsFingerprint daemon} but addons scope is nixpkgs-${pkgsFingerprint actual}; draw both from ONE nixpkgs instance — see fix 995d8c9 and docs/modules/interface-standards.md §5";
in
{
  inherit
    homeDir
    sopsBase
    sopsFile
    sopsRuntimePath
    pkgsFingerprint
    sameSource
    ;
}
