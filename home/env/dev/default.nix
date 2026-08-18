# @path: ~/projects/configs/nix-config/home/env/dev/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::env::dev::default
#
# Modern, fast C development environment with clangd + bear
# @Tips: Only this file combinFrom base dev shell
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language
#
# dev.<lang> == dev.<lang>.default


{ pkgs, inputs, shared, dev, ... }: {

  # (readonly)
  default = {
    shell = "zsh";
    combinFrom = [
      dev.asm
      dev.c
      dev.cpp
      dev.go
      dev.java
      dev.javascript
      dev.lisp
      dev.lua
      dev.nix
      dev.python
      dev.re
      dev.rust
      dev.typescript
      dev.zig
    ];
    buildInputs = with shared.upkgs; [];
    nativeBuildInputs = with shared.pkgs; [];
    preInputsHook = ''
      echo "[preInputsHook]: default shell!"
    '';
    postInputsHook = ''
      echo "[postInputsHook]: default shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: default shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: default shell!"
    '';
  };

  # (custom)
  cpython = {
    shell = "zsh";
    combinFrom = [
      dev.c
      dev.cpp
      dev.python
    ];
    buildInputs = with shared.upkgs; [];
    nativeBuildInputs = with shared.pkgs; [];
    preInputsHook = ''
      echo "[preInputsHook]: cpython shell!"
    '';
    postInputsHook = ''
      echo "[postInputsHook]: cpython shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: cpython shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: cpython shell!"
    '';
  };

  godot = {
    shell = "zsh";
    combinFrom = [
      dev.c
      dev.cpp
      dev.python
    ];
    buildInputs = with shared.upkgs; [ godot ];
    nativeBuildInputs = with shared.pkgs; [ ];

    preInputsHook = ''
      echo "[preInputsHook]: godot shell!"
    '';
    postInputsHook = ''
      echo "[postInputsHook]: godot shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: godot shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: godot shell!"
    '';

  };

  # os dev
  makeOs = {
    shell = "zsh";
    combinFrom = [
      dev.asm
      dev.c
    ];
    buildInputs = with shared.upkgs; [ zsh qemu_full just ];
    nativeBuildInputs = with shared.pkgs; [ ];

    preInputsHook = ''
      echo "[preInputsHook]: 30day make os shell!"
    '';
    postInputsHook = ''
      echo "[postInputsHook]: 30day make os shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: 30day make os shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: 30day make os shell!"
    '';
  };

  rs_compiler_dev = {
    shell = "zsh";
    combinFrom = [
      dev.c
      dev.rust
    ];
    buildInputs = with shared.upkgs; [
      zsh
      llvmPackages_22.llvm
    ];
    nativeBuildInputs = with shared.pkgs; [ ];
    preInputsHook = ''
      echo "[preInputsHook]: rust compiler dev shell!"
    '';
    postInputsHook = ''
      export CC="${shared.upkgs.llvmPackages_22.clang}/bin/clang"
      export CXX="${shared.upkgs.llvmPackages_22.clang}/bin/clang++"
      export AR="${shared.upkgs.llvmPackages_22.llvm}/bin/llvm-ar"
      export RANLIB="${shared.upkgs.llvmPackages_22.llvm}/bin/llvm-ranlib"
      export LLVM_SYS_211_PREFIX="${shared.upkgs.llvmPackages_22.llvm.dev}"
      export LLVM_LINK_SHARED=1
      export LD_LIBRARY_PATH="${shared.upkgs.llvmPackages_22.llvm.lib}/lib:$LD_LIBRARY_PATH"
      export RUSTFLAGS="-C linker=${shared.upkgs.llvmPackages_22.clang}/bin/clang -C link-arg=-fuse-ld=lld $RUSTFLAGS"
      export RUST_SRC_PATH="${shared.upkgs.rust.packages.stable.rustPlatform.rustLibSrc}"
      echo "[postInputsHook]: Rust + LLVM compiler dev shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: Rust + LLVM compiler dev shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: Rust + LLVM compiler dev shell!"
    '';
  };
}


