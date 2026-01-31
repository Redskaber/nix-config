# @path: ~/projects/configs/nix-config/home/core/dev/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::dev::default
#
# Modern, fast C development environment with clangd + bear
# @Tips: Only this file combinFrom base dev shell
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language
#
# dev.<lang> == dev.<lang>.default


{ pkgs, inputs, dev, ... }: {

  # (readonly)
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
    # buildInputs = with pkgs; [];
    # nativeBuildInputs = with pkgs; [];
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
    combinFrom = [
      dev.c
      dev.cpp
      dev.python
    ];
    # buildInputs = with pkgs; [];
    # nativeBuildInputs = with pkgs; [];
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

