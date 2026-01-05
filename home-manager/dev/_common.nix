# @path: ~/projects/nix-config/home-manager/dev/_common.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: all dev shell base env


{ pkgs, inputs, ... }: {
  default = pkgs.mkShell {
    buildInputs = with pkgs; [];
    nativeBuildInputs = with pkgs; [];
    shellHook = ''
      # auto inner env
      if [ -z "$__NIX_DEV_SHELL_SPAWNED" ]; then
        # Nix devshell flag
        export __NIX_DEV_SHELL_SPAWNED=1
        # exec ${pkgs.zsh}/bin/zsh -l
        exec ${pkgs.fish}/bin/fish
      fi
    '';
  };
}

