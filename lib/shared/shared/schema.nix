# @path: ~/projects/configs/nix-config/lib/shared/shared/schema.nix
# @author: redskaber
# @datetime: 2026-04-23
# @discription: lib::shared::shared::schema
# @directory: https://nix.dev/manual/nix/2.33/command-ref/new-cli/nix3-flake.html
# - nix core informations configuration

let
  user = {
    username          ,
    shell             ,
    openssh-authKeys  ,
  } @return_user: return_user;

  git = {
    defaultBranch     ,
    name              ,
    email             ,
    lazygit           ,
  } @return_git: return_git;

  rbw = {
    email             ,
    lock_timeout      ,
  } @return_rbw: return_rbw;

  time = {
    used-ip-timeZone  ,
    timeZone          ,
  } @return_time: return_time;

  i18n = {
    defaultLocale     ,
    extraLocale       ,
  } @return_i18n: return_i18n;

  secrets = {
    user-password             ,
    nixos-github-git-visited  ,
    mongodb-user-password     ,
    mysql-root-password       ,
    mysql-user-password       ,
    postgresql-user-password  ,
    redis-user-password       ,
  } @return_secrets: return_secrets;

  nixpkgs_config = {
    allowUnfree               ? true,
    permittedInsecurePackages ? [],
  } @return_nixpkgs_config: return_nixpkgs_config;

  nixpkgs = {
    overlays        ? [ ],
    config          ? nixpkgs_config,
  } @return_nixpkgs: return_nixpkgs;

  shared = {
    arch            ,
    drive           ,
    platform        ,
    window-manager  ,
    version         ,
    editor          ,
    devDir          ,
    hostName        ,
    user            ,
    git             ,
    rbw             ,
    time            ,
    i18n            ,
    secrets         ,
    nixpkgs         ,
    ...
  } @return_shared: return_shared;

in {
  inherit
    user
    git
    rbw
    time
    i18n
    secrets
    nixpkgs
    shared
  ;
}


