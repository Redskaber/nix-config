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
    buildInputs = with pkgs; [];
    nativeBuildInputs = with pkgs; [];
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
    buildInputs = with pkgs; [];
    nativeBuildInputs = with pkgs; [];
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
    buildInputs = with pkgs; [ godot ];
    nativeBuildInputs = with pkgs; [ ];

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
    nativeBuildInputs = with pkgs; [ ];

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
    buildInputs = with shared.upkgs; [ zsh llvm ];
    nativeBuildInputs = with pkgs; [ ];
    preInputsHook = ''
      echo "[preInputsHook]: rust compiler dev shell!"
    '';
    postInputsHook = ''
      # export PATH="${pkgs.llvm}/bin:$PATH"
      export CXX="${pkgs.clang}/bin/clang++"
      export AR="${pkgs.llvm}/bin/llvm-ar"
      export RANLIB="${pkgs.llvm}/bin/llvm-ranlib"
      export RUSTFLAGS="-C linker=${pkgs.lld}/bin/ld.lld $RUSTFLAGS"
      export RUST_SRC_PATH="${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}"
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


