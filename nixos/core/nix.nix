# @path: ~/projects/configs/nix-config/nixos/core/nix.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::core::nix
# @origin: https://search.nixos.org/options?channel=25.11&query=nix.


{ inputs
, config
, lib
, pkgs
, ...
}:
let
  flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
in
{
  nix = {

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };

    settings = {
      auto-optimise-store = true;
      # Enable flakes and new 'nix' command
      experimental-features = [
        "nix-command"         # nix-shell
        "flakes"              # flake
        "pipe-operators"      # nix pipe |>
      ];
      # Opinionated: disable global registry
      flake-registry = "";
      # downloads and updated mapping original
      substituters = [
        "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
        "https://mirror.sjtu.edu.cn/nix-channels/store"
        "https://mirrors.ustc.edu.cn/nix-channels/store"
        "https://nix-community.cachix.org"
        "https://nix-gaming.cachix.org"
        "https://hyprland.cachix.org"

      ];
      # command: 'nix config show | grep trusted-public-keys'
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];
      # trusted useds
      trusted-users = [ "kilig" ];
    };

    # Opinionated: disable channels
    channel.enable = false;

    # Opinionated: make flake registry and nix path match flake inputs
    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };
}


