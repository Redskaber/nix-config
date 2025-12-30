# @path: ~/projects/nix-config/home-manager/app/git.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.git.enable


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
      push.autoSetupTemote = true;
    };
  };
}



    
    
    
    

