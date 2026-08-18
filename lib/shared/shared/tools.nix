# @path: ~/projects/configs/nix-config/lib/shared/shared/tools.nix
# @author: redskaber
# @datetime: 2026-03-15
# @description: lib::shared::shared::tools — external tool library registry
#
# Design:
#   Centralizes all external tool library access (nix-types, orc, pdshell).
#   Configuration files use `shared.tools.<name>.<api>` instead of
#   `inputs.<long-name>.lib.<api>`, keeping config files clean and
#   decoupling them from flake input names.
#
#   Layer: lib/shared (Phase 1, no pkgs dependency)
#   Consumed by: runtime/default.nix (injects into shared.tools)
#   Config files: shared.tools.nix-types.match, shared.tools.orc.mergeHomeFiles
#
# Principle:
#   - Tools are organized here, not scattered across config files
#   - Short paths: shared.tools.nt instead of inputs.nix-types.lib
#   - Config files do not reference inputs directly for tool access

{ inputs, ... }:
let
  # nix-types: ADT system (enum, match, Option, Result, serialize, predicates)
  nt = inputs.nix-types.lib;

  # configuration-orchestrator: config file tree merge/copy/symlink engine
  # Note: orc is arch-specific (lib.${system}), resolved at runtime
  orc-lib = inputs.configuration-orchestrator.lib;

  # pdshell: pipeline-driven dev shell manager
  pdshell-lib = inputs.pdshell.lib;
in {
  # nix-types (short alias: nt)
  nix-types = nt;
  nt = nt;  # convenience alias

  # configuration-orchestrator (resolved per-arch at runtime)
  orc-raw = orc-lib;

  # pdshell (resolved at runtime)
  pdshell-raw = pdshell-lib;
}
