# @path: ~/projects/configs/nix-config/export/home/default.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: export::home — reusable Home Manager modules (registry)

# Options-first standalone modules — no `shared` dependency, importable
# from any external flake via `inputs.nix-config.homeModules.<name>`.
# Interface standards: docs/modules/interface-standards.md
{
  fcitx5 = import ./fcitx5.nix;
  shell = import ./shell.nix;
  waybar = import ./waybar.nix;
  yazi = import ./yazi.nix;
}
