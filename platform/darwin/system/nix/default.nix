# @path: ~/projects/configs/nix-config/platform/darwin/system/nix/default.nix
# @author: redskaber
# @datetime: 2026-10-15
# @description: platform::darwin::system::nix — the darwin nix settings
# @origin: https://github.com/LnL7/nix-darwin/blob/master/modules/nix/default.nix
#
# The darwin twin of the nixos customs' core/base/nix.nix: the
# host-side pull half of the fleet-cache story, composed BY VALUE
# from the same identity SSOT (shared.const.cache.fleet,
# lib/shared/lang/const.nix). nix-darwin renders nix.settings into
# /etc/nix/nix.conf, taking the file over from the installer's copy
# (its known-hash allowlist), so a darwin-rebuild switch lands this
# policy on the machine exactly like nixos-rebuild lands the nixos
# twin — the fourth and last pull-side plane: CI runners, nixos
# hosts, flake metadata, and now the darwin host closure.
#
# Posture parity follows plane CAPABILITY, not option names — every
# delta is upstream grammar, never local preference:
#   - nix.gc is a launchd daemon here (interval, not dates):
#     Sunday 03:15 mirrors the nixos weekly cadence;
#   - no sops-nix on darwin — the github access-token !include is
#     a nixos-only secret-stack concern;
#   - nix.package stays at nix-darwin's managed default (pkgs.nix
#     either way — pinning it again buys nothing);
#   - build users are managed unconditionally when nix.enable
#     (nix-darwin removed nix.configureBuildUsers);
#   - checkConfig is on by default, like its nixos twin.
#
# The substituter LIST is host-class policy, not identity: the fleet
# cache heads it (the one SSOT value), the CN mirrors and the caches
# a darwin closure actually consults follow (nix-community carries
# nix-darwin itself), and the linux-desktop/sops caches the nixos
# list carries are absent — capability-scoped, not forgotten. Query
# order follows each cache's advertised priority (ours is 41,
# behind cache.nixos.org's 40): shared paths come official, this
# cache serves only what official lacks.

{
  inputs,
  shared,
  lib,
  ...
}:
let
  flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
in
{
  nix = {
    # Flakes carry the input story; channel state files stay off the
    # machine (also drops nix-channel from the profile).
    channel.enable = false;

    gc = {
      automatic = true;
      interval = [
        {
          Weekday = 7;
          Hour = 3;
          Minute = 15;
        }
      ];
      options = "--delete-older-than 30d";
    };

    settings = {
      auto-optimise-store = true;
      # Enable flakes and new 'nix' command
      experimental-features = [
        "nix-command" # nix-shell
        "flakes" # flake
        "pipe-operators" # nix pipe |>
      ];
      # Opinionated: disable global registry
      flake-registry = "";
      # downloads and updated mapping original
      # The fleet's own cache heads the list — identity single-sourced
      # in lib/shared/lang/const.nix (shared.const.cache.fleet); this
      # module is the darwin plane that consumes it BY VALUE (same
      # composition as the nixos customs' core/base/nix.nix). The CI
      # push half lives in .github/workflows/ci.yml behind
      # secret.CACHIX_AUTH_TOKEN. The literal mirrors in the YAML/
      # just/flake-metadata planes are pinned by tests/cache-ssot.nix.
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
      # trusted users
      trusted-users = [ shared.user.username ];
    };

    # Opinionated: make flake registry and nix path match flake inputs
    registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };
}
