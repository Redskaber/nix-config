# @path: ~/projects/configs/nix-config/tests/pre-commit.nix
# @author: redskaber
# @datetime: 2026-10-09
# @description: tests::pre-commit — git-hooks eval gate (checks half)
# @directory: https://github.com/cachix/git-hooks.nix
#
# The pre-commit half of `checks` (T5.1): moved out of flake.nix so the
# entry file only maps names. Composed in flake.nix as
#
#   checks.<sys> = (import ./tests { … }) // (import ./tests/pre-commit.nix { … });
#
# NOTE(fix): git-hooks.nix removed the `nixfmt-rfc-style` hook alias —
# its formatter merged into plain `nixfmt` (nixfmt ≥0.6 speaks RFC-116
# style) — and `lib.<sys>.run` returns the check DERIVATION directly,
# not `{ pre-commit-check }`. Merging it with `//` used to spill drv
# attrs (outPath/drvPath/…) into checks and silently DROP the hook
# entry from the output set (shallow CI eval never noticed). Assign it
# under its proper attr name — `nix flake check --no-build` is the gate
# that keeps this wiring honest.

{
  inputs,
  self,
  shared,
  ...
}:
{
  pre-commit-check = inputs.pre-commit-hooks.lib.${shared.arch.tag}.run {
    src = self;
    hooks = {
      nixfmt = {
        enable = true;
        excludes = [
          "flake.lock"
          ".*-config/.*"
        ];
      };
      statix.enable = true;
      # deadnix gates on dead `let` bindings (the real dead-code class).
      # `--no-lambda-pattern-names` / `--no-lambda-arg` exempt the
      # idiomatic signatures this tree standardises on: uniform module
      # heads ({ inputs, shared, lib, config, pkgs, ... }) and overlay
      # pairs (final: prev:).
      deadnix = {
        enable = true;
        settings = {
          noLambdaPatternNames = true;
          noLambdaArg = true;
        };
      };
    };
  };
}
