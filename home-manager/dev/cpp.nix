# @path: ～/projects/nix-config/home-manager/dev/cpp.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: Modern C++ dev environment: clang + clangd + build tools


{ pkgs, inputs, ... }: {
  default = pkgs.mkShell {
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

    shellHook = ''
      # Use Clang as default compiler (better diagnostics & LSP sync)
      export CC=${pkgs.clang}/bin/clang
      export CXX=${pkgs.clang}/bin/clang++

      # Optional: set standard (e.g., C++20)
      # export CXXFLAGS="-std=c++20 -Wall -Wextra"
      # echo "C++ dev env ready: compiler=clang++, LSP=clangd"
    '';
  };
}
