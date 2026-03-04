# @path: ~/projects/configs/nix-config/lib/shared/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: lib::shared::default
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - user informations configuration

let
  is_linux = false;
  is_macos = false;
  is_nixos = true;
  is_wsl = false;
in
{
  inherit is_linux is_macos is_nixos is_wsl;

  editor = "nvim";
  user = {
    username = "kilig";
    shell = "fish";
    openssh-authKeys = [  ];
  };

  git = {
    defaultBranch = "main";
    name = "redskaber";
    email = "redskaber@foxmail.com";
    lazygit.name = "lg";
  };

  rbw = {
    email = "alexredskaber@gmail.com";
    lock_timeout = 600;
  };

  time = {
    used-ip-timeZone = false;
    timeZone = "Asia/Shanghai";
  };

  arch = "x86_64-linux";
  hostName =
    if      is_linux then "linux"
    else if is_macos then "macos"
    else if is_nixos then "nixos"
    else if is_wsl   then "wsl"
    else throw "[ERROR] Non-sup ${builtins.currentSystem}, can't build, issues or waiting dev";
  version = "25.11";
}


