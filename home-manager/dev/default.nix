# @path: ~/projects/nix-config/home-manager/dev/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: Modern, fast C development environment with clangd + bear


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
      echo "[preInputsHook]: default hell!"
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
}

