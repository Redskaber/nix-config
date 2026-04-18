# @path: ~/projects/configs/nix-config/lib/shared/schema.nix
# @author: redskaber
# @datetime: 2025-12-12
# @discription: lib::shared::schema
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - nix core informations configuration

{ inputs, nixpkgs, ... }:
let
  inherit (inputs.nix-types.enum) enum;

  const = {
    devDir  = "home/core/dev";
    hostName= "nixos";
    user    = {
      username          = "example";
      shell             = shell.zsh;
      openssh-authKeys  = [ ];
    };
    git     = {
      defaultBranch     = "main";
      name              = "example";
      email             = "example@gmail.com";
      lazygit.name      = "lg";
    };
    rbw     = {
      email             = "example@gmail.com";
      lock_timeout      = 1000;
    };
    time    = {
      used-ip-timeZone  = false;
      timeZone          = "Asia/Shanghai";
    };
    secrets = {
      user-password             = "nixos.core.base.users.kilig.password";
      nixos-github-git-visited  = "nixos.core.base.nix.kilig.nixos-github-git-visited";
      mongodb-user-password     = "nixos.core.srv.db.mongodb.users.kilig.password";
      mysql-root-password       = "nixos.core.srv.db.mysql.users.root.password";
      mysql-user-password       = "nixos.core.srv.db.mysql.users.kilig.password";
      postgresql-user-password  = "nixos.core.srv.db.postgresql.users.kilig.password";
      redis-user-password       = "nixos.core.srv.db.redis.users.redis-kilig.password";
    };
    nixpkgs = {
      overlays  = [ ];
      config    = {
        allowUnfree               = true;
        permittedInsecurePackages = [ ];
      };
    };
  };

  editor    = enum "editor"   [ "vim" "nvim" "code" "zeditor" ];
  version   = enum "version"  {
    v25_11  = "25.11";
  };
  platform        = enum "platform"       [ "linux" "macos" "nixos" "wsl" ];
  arch            = enum "arch"           [ "aarch64-darwin" "aarch64-linux" "i686-linux" "x86_64-darwin" "x86_64-linux" ];

  portal          = enum "portal" {
    gtk           = "xdg-desktop-portal-gtk";
    wlr           = "xdg-desktop-portal-wlr";
    hyprland      = "xdg-desktop-portal-hyprland";
  };
  window-manager  = enum "windowManager" {
    gnome         = { default = [ "gtk"           ]; portals = [ portal.gtk                 ]; };
    niri          = { default = [ "wlr" "gtk"     ]; portals = [ portal.gtk portal.wlr      ]; };
    hyprland      = { default = [ "hyprland" "gtk"]; portals = [ portal.gtk portal.hyprland ]; };
  };

  display-manager = enum "displayManager" [ "gdm" "ly" "sddm" ];
  drive           = enum "drive"          [ "amd" "intel" "nvidia" "nvidia-prime" ];
  drive-group     = enum "driveGroup"     {
    amd               = [ "amd" ];
    intel             = [ "intel" ];
    nvidia            = [ "nvidia" ];
    nvidia-prime      = [ "nvidia-prime" ];
    amd-nvidia        = [ "amd" "nvidia" ];
    amd-nvidia-prime  = [ "amd" "nvidia-prime" ];
    intel-nvidia      = [ "intel" "nvidia" ];
    intel-nvidia-prime= [ "intel" "nvidia-prime" ];
  };
  shell           = enum "shell"          [ "bash" "zsh" "fish" ];

  # --- config --- 
  struct = {
    user = {
      username          ? const.user.username,
      shell             ? const.user.shell,
      openssh-authKeys  ? const.user.openssh-authKeys,
    } @return_user: return_user;

    git = {
      defaultBranch     ? const.git.defaultBranch,
      name              ? const.git.name,
      email             ? const.git.email,
      lazygit           ? const.git.lazygit,
    } @return_git: return_git;

    rbw = {
      email             ? const.rbw.email,
      lock_timeout      ? const.rbw.lock_timeout,
    } @return_rbw: return_rbw;

    time = {
      used-ip-timeZone  ? const.time.used-ip-timeZone,
      timeZone          ? const.time.timeZone,
    } @return_time: return_time;

    secrets = {
      user-password             ? const.secrets.user-password,
      nixos-github-git-visited  ? const.secrets.nixos-github-git-visited,
      mongodb-user-password     ? const.secrets.mongodb-user-password,
      mysql-root-password       ? const.secrets.mysql-root-password,
      mysql-user-password       ? const.secrets.mysql-user-password,
      postgresql-user-password  ? const.secrets.postgresql-user-password,
      redis-user-password       ? const.secrets.redis-user-password,
    } @return_secrets: return_secrets;

    nixpkgs_config = {
      allowUnfree               ? true,
      permittedInsecurePackages ? [],
    } @return_nixpkgs_config: return_nixpkgs_config;

    nixpkgs = {
      overlays        ? [ ],
      config          ? struct.nixpkgs_config,
    } @return_nixpkgs: return_nixpkgs;

    shared = {
      arch            ? arch.x86_64-linux,
      drive           ? drive.intel,
      platform        ? platform.linux,
      window-manager  ? window-manager.hyprland,
      version         ? version.v25_11,
      editor          ? editor.nvim,
      devDir          ? const.devDir,
      hostName        ? const.hostName,
      user            ? struct.user,
      git             ? struct.git,
      rbw             ? struct.rbw,
      time            ? struct.time,
      secrets         ? struct.secrets,
      nixpkgs         ? struct.nixpkgs,
      ...
    } @return_shared: return_shared;
  };

  fn-init-secrets = username:
    struct.secrets {
      user-password             = "nixos.core.base.users.${username}.password";
      nixos-github-git-visited  = "nixos.core.base.nix.${username}.nixos-github-git-visited";
      mongodb-user-password     = "nixos.core.srv.db.mongodb.users.${username}.password";
      mysql-root-password       = "nixos.core.srv.db.mysql.users.root.password";
      mysql-user-password       = "nixos.core.srv.db.mysql.users.${username}.password";
      postgresql-user-password  = "nixos.core.srv.db.postgresql.users.${username}.password";
      redis-user-password       = "nixos.core.srv.db.redis.users.redis-${username}.password";
    };

  secrets = struct.secrets;
  pkgs = nixpkgs.legacyPackages.${arch.x86_64-linux.tag};  # jocker pkgs
in {
  inherit
    editor version platform arch window-manager display-manager drive drive-group shell
    struct secrets pkgs
    fn-init-secrets
  ;
}


