# @path: ~/projects/configs/nix-config/pkgs/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: pkgs::default — custom packages (placeholder)

# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  # example = pkgs.callPackage ./example { };
  # wslview: minimal "open on the Windows side" shim (T3.1) — replaces
  # the archived wslu package this tree used to consume.
  wslview = pkgs.callPackage ./wslview { };
}
