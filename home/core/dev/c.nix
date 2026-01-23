# @path: ~/projects/configs/nix-config/home/core/dev/c.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::dev::c
#
# Modern, fast C development environment with clangd + bear
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, dev, ... }: {
  default = {

    buildInputs = with pkgs; [
      # gcc               # GNU toolchain (fallback or specific needs)
      clang               # Primary C compiler (recommended)
      clang-tools         # Provides clangd (LSP), clang-tidy, etc.
      lld                 # Fast LLVM linker (optional but recommended)

      lldb                # Debugger (gdb)
      bear                # Generates compile_commands.json for LSP/tools
      ccache              # Compiler cache (transparent speedup)
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
      cmake
      ninja
    ];
    preInputsHook = ''
      echo "[preInputsHook]: c shell!"
    '';
    postInputsHook = ''
      # Use Clang as default C compiler (modern, better diagnostics)
      export CC="ccache  ${pkgs.clang}/bin/clang -fuse-ld=lld"
      # export C_INCLUDE_PATH=" ${pkgs.glibc.dev}/include"

      export CLANG_COLOR_DIAGNOSTICS=always
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

