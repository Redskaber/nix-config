# @path: ~/projects/configs/nix-config/home/core/dev/cpp.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::dev::cpp
#
# Modern C++ dev environment: clang + clangd + build tools
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, dev, ... }: {
  default = {

    buildInputs = with pkgs; [
      gcc                 # GNU toolchain (fallback)
      clang               # Primary C/C++ compiler
      clang-tools         # Provides clangd, clang-tidy, clang-format
      llvm                # LLVM utilities (opt, llc, etc.)
      gdb                 # Debugger
      bear                # Generates compile_commands.json
      boost               # Popular C++ libraries
      eigen               # Linear algebra (common in scientific computing)
      # vcpkg             # Optional: uncomment if you use vcpkg for deps
      # openblas
      # lapack
      # fmt
      # spdlog
      # conan
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
      cmake
      meson
      ninja
    ];

    preInputsHook = ''
      echo "[preInputsHook]: cpp shell!"
    '';
    postInputsHook = ''
      # Use Clang as default compiler (better diagnostics & LSP sync)
      export CC=${pkgs.clang}/bin/clang
      export CXX=${pkgs.clang}/bin/clang++

      # Optional: set standard (e.g., C++20)
      # export CXXFLAGS="-std=c++20 -Wall -Wextra"
      # echo "C++ dev env ready: compiler=clang++, LSP=clangd"
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
