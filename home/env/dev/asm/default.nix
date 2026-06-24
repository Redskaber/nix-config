# @path: ~/projects/configs/nix-config/home/env/dev/asm/default.nix
# @author: redskaber
# @datetime: 2026-06-24
# @description: home::env::dev::asm::default
#
# Assembly development environment with nasm + binutils
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): baseline assembly toolchain
# - <variant> : (custom     , custom, optional  ): specific feature or version

{ pkgs, inputs, shared, dev, ... }: {
  default = {
    shell = "zsh";
    buildInputs = with pkgs; [
      nasm                     # Netwide Assembler (primary assembler)
      nasmfmt                  # Netwide Assembler formatter
      binutils                 # Provides ld (linker), objdump, readelf, etc.
      gdb                      # GNU debugger (for assembly-level debugging)
      # (Optional) gcc         # Only if you need libc or C runtime for linking
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
      gnumake                  # Optional build automation (for Makefile projects)
    ];

    preInputsHook = ''
      echo "[preInputsHook]: assembly environment loading..."
    '';

    postInputsHook = ''
      echo "[postInputsHook]: assembly environment ready..."
    '';

    preShellHook = ''
      echo "[preShellHook]: entering assembly shell..."
    '';

    postShellHook = ''
      echo "[postShellHook]: assembly shell active."
    '';
  };
}
