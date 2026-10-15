# @path: ~/projects/configs/nix-config/home/core/base/nix.nix
# @author: redskaber
# @datetime: 2026-10-16
# @description: home::core::base::nix — the user-domain nix settings plane
# @origin: https://nix-community.github.io/home-manager/options.xhtml#nix.settings
#
# The user-domain twin of the system customs' nix planes
# (platform/nixos/system/core/base/nix.nix + platform/darwin/
# system/nix) — the THIRD by-value consumer of the fleet cache
# identity, and the one plane the fleet could not reach before:
# a standalone home-manager host (hosts/wsl — a WSL distro whose
# system layer this flake does not own) has no system emitter to
# render /etc/nix/nix.conf, so ~/.config/nix/nix.conf is the only
# declaratively managed nix config the closure can land.
#
# home-manager's own misc/nix module is the carrier (knowledge-
# searched, the equivalent of the system twins' grammar): nix.*
# options render xdg.configFile."nix/nix.conf" through a real
# derivation whose checkPhase runs `nix config show` over the
# generated file — the settings names are validated at BUILD time,
# the same contract nix.settings gives the system planes.
#
# Gate — capability-scoped, not forgotten (the darwin twin's
# posture): the module reads ONE resolved fact, the new caps
# column system-nix (lib/shared/lang/enum.nix). Where a system
# plane renders /etc/nix/nix.conf (nixos · nixos-wsl · darwin)
# this stays SILENT: per the nix.conf priority chain
# (built-in < /etc/nix/nix.conf < ~/.config/nix/nix.conf), a user
# file would shadow the system one per-setting and list-type
# settings replace wholesale — a second copy of host-class policy
# with nothing to win and everything to drift. Where no system
# plane exists (linux · wsl), the user file is the fleet's plane.
#
# Priority-chain notes for the machines this file serves:
#   - the user file overrides the distro's global nix.conf
#     per-setting (experimental-features etc. fully effective);
#   - substituters/keys are honoured when the user is trusted by
#     the daemon (single-user installs need no trust) — trust on
#     a distro-owned daemon is the machine-side prerequisite,
#     the same trust the system twins grant explicitly;
#   - no sops-nix standalone: the github access-token !include is
#     a nixos-only secret-stack concern (same delta as darwin);
#   - no nix.gc here: home-manager has no store-gc capability —
#     the distro's daemon owns collection (posture parity follows
#     plane capability, never option names).
#
# The substituter LIST is host-class policy, not identity: the
# fleet cache heads it (the one SSOT value, consumed BY VALUE
# from shared.const.cache.fleet, lib/shared/lang/const.nix),
# followed by the caches a standalone user closure actually
# consults — home-manager itself rides nix-community — the same
# composition as the darwin plane. Query order follows each
# cache's advertised priority (ours is 41, behind
# cache.nixos.org's 40): shared paths come official, this cache
# serves only what official lacks.

{
  inputs,
  shared,
  lib,
  pkgs,
  ...
}:
let
  flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
in
{
  config = lib.mkIf (!shared.caps.system-nix) {
    # Drives the build-time `nix config show` validation of the
    # generated file (the module asserts a package whenever
    # settings are non-empty — the twins' checkConfig analogue).
    # mkDefault: module-mode host wiring (HM's nixos/common.nix)
    # supplies its own per-user package default — same value, and
    # the standalone forms (no such wiring) still satisfy the
    # assertion through this default.
    nix.package = lib.mkDefault pkgs.nix;

    nix.settings = {
      auto-optimise-store = true;
      # Enable flakes and new 'nix' command
      experimental-features = [
        "nix-command" # nix-shell
        "flakes" # flake
        "pipe-operators" # nix pipe |>
      ];
      # Opinionated: disable global registry — the per-input user
      # registry below replaces it (the system twins' stance, user-
      # domain form; without it bare `nixpkgs#` refs would break).
      flake-registry = "";
      # downloads and updated mapping original
      substituters = [
        shared.const.cache.fleet.url
        "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
        "https://mirrors.ustc.edu.cn/nix-channels/store"
        "https://nix-community.cachix.org"
        "https://cache.nixos.org"
      ];
      # command: 'nix config show | grep trusted-public-keys'
      trusted-public-keys = [
        shared.const.cache.fleet.publicKey
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };

    # Opinionated: make flake registry and nix path match flake
    # inputs — the user-domain rendering of the system twins'
    # nix.registry/nixPath (registry.json lands in ~/.config/nix/,
    # NIX_PATH rides home.sessionVariables).
    nix.registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
    nix.nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };
}
