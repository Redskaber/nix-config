# @path: ~/projects/configs/nix-config/platform/nixos/system/core/base/nix.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: platform::nixos::core::base::nix
# @origin: https://search.nixos.org/options?channel=25.11&query=nix.

{
  inputs,
  shared,
  config,
  lib,
  pkgs,
  ...
}:
let
  flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
in
{
  nix = {
    enable = true;
    package = pkgs.nix;
    checkConfig = true;
    channel.enable = false;

    # nix access token to github dy imp
    extraOptions = ''
      !include ${config.sops.secrets.${shared.secrets.nixos.core.base.nix.user.github.access-token}.path}
    '';

    gc = {
      automatic = true;
      dates = "weekly";
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
      # module is the one plane that consumes it BY VALUE. The CI push
      # half lives in .github/workflows/ci.yml behind
      # secret.CACHIX_AUTH_TOKEN. List order is documentation only —
      # query order follows each cache's advertised priority (ours is
      # 41, behind cache.nixos.org's 40), so paths both hold always
      # come official and this cache serves only what official lacks.
      # Pull/push guide: docs/guides/cache.md; the literal mirrors in
      # the YAML/just/flake-metadata planes are pinned by
      # tests/cache-ssot.nix.
      substituters = [
        shared.const.cache.fleet.url
        "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
        "https://mirrors.ustc.edu.cn/nix-channels/store"
        "https://nix-community.cachix.org"
        "https://nix-gaming.cachix.org"
        "https://hyprland.cachix.org"
        "https://cache.nixos.org"
        # sops
        "https://mic92.cachix.org"
        "https://cache.thalheim.io"

      ];
      # command: 'nix config show | grep trusted-public-keys'
      trusted-public-keys = [
        shared.const.cache.fleet.publicKey
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        # sops
        "cache.thalheim.io-1:R7msbosLEZKrxk/lKxf9BTjOOH7Ax3H0Qj0/6wiHOgc="
        "mic92.cachix.org-1:gi8IhgiT3CYZnJsaW7fxznzTkMUOn1RY4GmXdT/nXYQ="
      ];
      # trusted useds
      trusted-users = [ shared.user.username ];
    };

    # Opinionated: make flake registry and nix path match flake inputs
    registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };
}
