# @path: ~/projects/configs/nix-config/home/core/dev/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: Modern, fast C development environment with clangd + bear
# @Tips: Only this file combinFrom base dev shell


{ pkgs, inputs, dev, ... }: {
  default = {
    combinFrom = [
      dev.c
      dev.cpp
      dev.java
      dev.javascript
      dev.lua
      dev.nix
      dev.python
      dev.rust
      dev.typescript
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
  cpython = {
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
}

