# @path: ~/projects/configs/nix-config/src/core/app/git.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/src/options.xhtml#opt-programs.git.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  programs.git = {
    enable = true;
    settings = {
      init = {
        defaultBranch = "main";
      };
      user = {
        name = "redskaber";
	      email = "redskaber@foxmail.com";
      };
      core.editor = "nvim";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
    ignores = [
      ".DS_Store"
      ".direnv"     # direnv
      ".cache"      # devShell
      ".venv"       # uv
      "*.swp"
      "*~"
    ];
  };
}








