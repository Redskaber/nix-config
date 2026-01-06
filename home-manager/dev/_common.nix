# @path: ~/projects/nix-config/home-manager/dev/_common.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: all dev shell base env


{ pkgs, inputs, mkDevShell, ... }: {
  default = mkDevShell {
    buildInputs = with pkgs; [];
    nativeBuildInputs = with pkgs; [];
    preInputsHook = ''
      echo "[preInputsHook]: _common shell!"
    '';
    postInputsHook = ''
      echo "[postInputsHook]: _common shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: _common shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: _common shell!"
    '';
  };
}

