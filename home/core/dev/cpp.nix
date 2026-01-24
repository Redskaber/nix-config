# @path: ~/projects/configs/nix-config/home/core/dev/cpp.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::dev::cpp
#
# Modern C++ dev environment: clang + clangd + build tools
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language
# FIXME: clangd in NixOS header find is idiot, waiting fix Neovim lsp used non-nixos (mason false).


{ pkgs, inputs, dev, ... }: {
  default = {

    buildInputs = with pkgs; [
      clang-tools         # Provides clangd, clang-tidy, clang-format
      clang               # Primary C/C++ compiler
      libcxx              # Clang's C++ standard library
      lld                 # Fast LLVM linker (optional but recommended)
      llvm                # LLVM utilities (opt, llc, etc.)
      lldb                # Debugger
      bear                # Generates compile_commands.json
      fmt                 # Essential modern C++ libs (header-only, widely used)
      spdlog
      eigen               # Linear algebra (common in scientific computing)
      ccache              # Compiler cache (transparent speedup)
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
      cmake
      ninja
    ];

    preInputsHook = ''
      echo "[preInputsHook]: cpp shell!"
    '';
    postInputsHook = ''
      # Use Clang as default compiler (better diagnostics & LSP sync)
      export CC="ccache ${pkgs.clang}/bin/clang"
      export CXX="ccache ${pkgs.clang}/bin/clang++"
      export C_INCLUDE_PATH=" ${pkgs.glibc.dev}/include"
      export CPLUS_INCLUDE_PATH=" ${pkgs.libcxx.dev}/include/c++/v1: ${pkgs.glibc.dev}/include"

      # Enable color diagnostics by default
      export CLANG_COLOR_DIAGNOSTICS=always

      # Optional: set default standard (commented to avoid side effects in generic env)
      # export CXXFLAGS="-std=c++20 -Wall -Wextra -Wpedantic -fdiagnostics-color=always"
      echo "[postInputsHook]: cpp shell!"
    '';
     preShellHook = ''
      echo "[preShellHook]: cpp shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: cpp shell!"
    '';
  };
}
