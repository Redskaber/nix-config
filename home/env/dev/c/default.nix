# @path: ~/projects/configs/nix-config/home/env/dev/c/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::env::dev::c::default
#
# Modern, fast C development environment with clangd + bear
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, shared, dev, ... }: {
  default = {
    shell = "zsh";
    buildInputs = with shared.upkgs; [
      # gcc                     # GNU toolchain (fallback or specific needs)
      glibc                     # C Library (macos musl)

      llvmPackages_22.clang     # Primary C compiler (recommended)
      llvmPackages_22.clang-tools # Provides clangd (LSP), clang-tidy, etc.
      llvmPackages_22.lld       # Fast LLVM linker (optional but recommended)
      llvmPackages_22.lldb      # LLVM debugger
      # llvmPackages_22.libc    # LLVM STD libc

      # Build & analysis
      bear                      # Generates compile_commands.json for LSP/tools
      ccache                    # Compiler cache (transparent speedup)
    ];

    nativeBuildInputs = with shared.pkgs; [
      pkg-config
      cmake
      ninja
    ];
    preInputsHook = ''
      echo "[preInputsHook]: c shell!"
    '';
    postInputsHook = ''
      # Use Clang as default C compiler (modern, better diagnostics)
      export CC="ccache  ${shared.upkgs.llvmPackages_22.clang}/bin/clang"
      export C_INCLUDE_PATH="${shared.upkgs.glibc.dev}/include"

      # Force use of lld linker
      export LD=${shared.upkgs.llvmPackages_22.lld}/bin/ld.lld
      export LDFLAGS="-fuse-ld=lld"
      export CLANG_COLOR_DIAGNOSTICS=always
      # Optional: Symbols
      export CFLAGS=" $CFLAGS -g"

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


