# @path: ~/projects/configs/nix-config/home/core/dev/zig/default.nix
# @author: redskaber
# @datetime: 2026-02-08
# @description: home::core::dev::zig:default
#
# Minimal, reproducible Zig development environment using nixpkgs' stable Zig toolchain.
# Fully offline-capable, flakes-compatible, and optimized for modern Zig workflows.
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): Minimal Zig toolchain + essential dev utilities
# - <variant> : (custom     , custom, optional  ): Version-specific or feature-rich configurations

{ pkgs, inputs, dev, ... }: {
  default = {

    # === Core Toolchain ===
    buildInputs = with pkgs; [
      zig             # Zig compiler (nixpkgs stable, usually the latest LTS)
      zls             # Zig Language Server (Official LSP, IDE Smart Support)
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config      # C library dependency discovery (required when Zig calls C code)
    ];

    preInputsHook = ''
      echo "[preInputsHook]: zig shell!"
    '';
    postInputsHook = ''
      echo "[postInputsHook]: zig shell!"
    '';
    preShellHook = ''
      # zig PATH default inject PATH
      # zls PATH default inject PATH
      echo "[preShellHook]: zig shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: zig shell!"
    '';
  };
}


