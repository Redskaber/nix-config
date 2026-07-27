# @path: ~/projects/configs/nix-config/home/env/dev/cpp/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::env::dev::cpp::default
#
# Pure LLVM-based Modern C++ dev environment:
# - Compiler: clang (via llvmPackages.libcxxClang)
# - Stdlib:   libc++ (not libstdc++)
# - Linker:   lld
# - Debugger: lldb
# - LSP:      clangd
#
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): minimal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language
#
# FIXME: clangd in NixOS header find is idiot, waiting fix Neovim lsp used non-nixos (mason false).

{ pkgs, inputs, shared, dev, ... }: {
  default = {
    shell = "zsh";
    buildInputs = with shared.pkgs; [
      # Core LLVM toolchain (pure)
      llvmPackages_21.libcxxClang # Clang++ preconfigured wrapper
      llvmPackages_21.libcxx      # provides libc++ and lib++abi
      llvmPackages_21.clang-tools # clangd, clang-tidy, clang-format
      llvmPackages_21.lld         # LLVM linker
      llvmPackages_21.lldb        # LLVM debugger
      llvmPackages_21.llvm        # opt, llc, etc.

      # Build & analysis
      bear                      # compile_commands.json
      ccache                    # compiler cache

      # Common modern C++ libraries (header-only or built against libc++)
      fmt
      spdlog
      eigen
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
      cmake
      ninja
    ];

    preInputsHook = ''
      echo "[preInputsHook]: pure LLVM C++ shell!"
    '';

    postInputsHook = ''
      # Use the pure libc++-aware Clang wrapper as default compilers
      export CC="ccache  ${shared.pkgs.llvmPackages_21.libcxxClang}/bin/clang"
      export CXX="ccache  ${shared.pkgs.llvmPackages_21.libcxxClang}/bin/clang++"

      # Explicitly set include paths to prefer libc++ headers
      # Note: glibc C headers are still needed (libc is glibc), but C++ must be libc++
      export C_INCLUDE_PATH="${shared.pkgs.glibc.dev}/include"
      export CPLUS_INCLUDE_PATH="${shared.pkgs.llvmPackages_21.libcxx.dev}/include/c++/v1:${shared.pkgs.glibc.dev}/include"

      # Force use of lld linker
      export LD=${shared.pkgs.llvmPackages_21.lld}/bin/ld.lld
      export LDFLAGS="-fuse-ld=lld"

      # Enable color diagnostics
      export CLANG_COLOR_DIAGNOSTICS=always

      # Runtime-Linker
      export LD_LIBRARY_PATH="${shared.pkgs.llvmPackages_21.libcxx}/lib:$LD_LIBRARY_PATH"

      # Optional: uncomment to enforce C++20+ in all builds (use cautiously in generic env)
      # export CXXFLAGS="-std=c++20 -stdlib=libc++ -Wall -Wextra -Wpedantic -fdiagnostics-color=always"
      # export LDFLAGS=" $LDFLAGS -lc++abi"

      echo "[postInputsHook]: pure LLVM C++ shell ready!"
    '';

    preShellHook = ''
      echo "[preShellHook]: entering pure LLVM C++ environment"
    '';

    postShellHook = ''
      echo "[postShellHook]: pure LLVM C++ environment active"
    '';
  };
}


