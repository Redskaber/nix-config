# @path: ~/projects/configs/nix-config/platform/nixos/home/x86_64-linux.nix
# @author: redskaber
# @datetime: 2026-03-07
# @description: platform::nixos::home::x86_64-linux — HM payload row (T5.11)
# @directory: https://nix-community.github.io/home-manager/options.xhtml

# The x86_64-linux arch row of platform/nixos' user domain (grammar
# v3: arch rows live INSIDE home/, next to the HM customs — the
# arch axis has an address in the user domain, exactly where it
# exists semantically). Mounted by the home customs ./default.nix
# (the standalone door) via the shared arch dispatch. This is your
# home-manager configuration file — it replaces
# ~/.config/nixpkgs/home.nix.
#
# The shared user-tree imports below cross FROM this platform's user
# domain INTO the cross-platform user library at the repo root
# (home/{core,env,wm} — content shared by every platform's payload;
# platform-specific user content stays in this subtree).
{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  home = {
    username = shared.user.username;
    homeDirectory = shared.homeDir;
    stateVersion = shared.version.value.stateVersion;
  };
  programs.home-manager.enable = true;

  # You can import other home-manager modules here
  imports = [
    # If you import other home-manager modules from other flakes (such as nix-colors):
    # You can also split up your configuration and import pieces of it here:
    ../../../home/core
    ../../../home/env
    ../../../home/wm
    # devShells: import dev/lang.nix from flake.nix
  ];

  # used user custom inxpkgs
  nixpkgs = shared.nixpkgs;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

}
