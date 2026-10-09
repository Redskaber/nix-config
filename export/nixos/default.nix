# @path: ~/projects/configs/nix-config/export/nixos/default.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: export::nixos — reusable NixOS modules (registry)

# Options-first standalone modules — no `shared` dependency, importable
# from any external flake via `inputs.nix-config.nixosModules.<name>`.
# Interface standards: docs/modules/interface-standards.md
{
  portal = import ./portal.nix;
  fcitx5 = import ./fcitx5.nix;
}
