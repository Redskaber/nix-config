# @path: ~/projects/configs/nix-config/platform/wsl/home/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: platform::wsl::home — the standalone-HM customs (T5.11)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# THE home-domain customs of platform/wsl. Directory grammar v3 —
# directory-as-domain (T5.11): WSL hosts run standalone HM only —
# no system form of its own (the WSL kernel side is owned by the
# Windows host), hence NO default.nix at the platform top level
# (file absence = capability declaration). The whole platform
# directory IS the user domain: home/ and nothing else. mkHomeSystem
# imports platform/<tag>/home (a directory reference); arch dispatch
# identical to the sibling platforms:
#
#   imports = [ ./${shared.arch.tag}.nix ]
{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./${shared.arch.tag}.nix
  ];
}
