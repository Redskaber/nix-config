# @path: ~/projects/nix-config/home-manager/dev/c.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: Modern, fast C development environment with clangd + bear


{ pkgs, inputs, ... }: {
  default = pkgs.mkShell {
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

    shellHook = ''
      # Use Clang as default C compiler (modern, better diagnostics)
      export CC=${pkgs.clang}/bin/clang

      # Optional: if you ever compile C++ in this env
      # export CXX=${pkgs.clang}/bin/clang++
      # echo "C dev env ready: CC=clang, LSP=clangd"
    '';
  };
}

