# @path: ~/projects/configs/nix-config/docs/example/dev/dm/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: docs::example::dev::dm::default
#
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
      dev.c                     # dev.c -> default used dev.c.default
      dev.python.machine        # can custom attrset
    ];

    # Optional extra
    buildInputs = with pkgs; [];
    nativeBuildInputs = with pkgs; [];
    preInputsHook = ''
      echo "[preInputsHook]: example default shell!"
    '';
    postInputsHook = ''
      echo "[postInputsHook]: example default shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: example default shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: example default shell!"
    '';
  };

  # (custom)
  cpython = {
    combinFrom = [
      dev.c
      dev.python
    ];

    # Optional extra
    buildInputs = with pkgs; [];
    nativeBuildInputs = with pkgs; [];
    preInputsHook = ''
      echo "[preInputsHook]: example cpython shell!"
    '';
    postInputsHook = ''
      echo "[postInputsHook]: example cpython shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: example cpython shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: example cpython shell!"
    '';
  };
}

