# @path: ~/projects/configs/nix-config/src/core/dev/c.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: Modern, fast C development environment with clangd + bear


{ pkgs, inputs, dev, ... }: {
  default = {

    buildInputs = with pkgs; [
      gcc                 # GNU toolchain (fallback or specific needs)
      clang               # Primary C compiler (recommended)
      clang-tools         # Provides clangd (LSP), clang-tidy, etc.
      gdb                 # Debugger
      bear                # Generates compile_commands.json for LSP/tools
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
      cmake
      meson
      ninja
    ];
    preInputsHook = ''
      echo "[preInputsHook]: c shell!"
    '';
    postInputsHook = ''
      # Use Clang as default C compiler (modern, better diagnostics)
      export CC=${pkgs.clang}/bin/clang

      # Optional: if you ever compile C++ in this env
      # export CXX=${pkgs.clang}/bin/clang++
      # echo "C dev env ready: CC=clang, LSP=clangd"
      echo "[postInputsHook]: c shell!"
    '';

    preShellHook = ''
      echo "[preShellHook]: c shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: c shell!"
    '';
  };
}

