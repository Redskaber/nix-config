# @path: ~/projects/configs/nix-config/platform/linux/home/default.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: platform::linux::home — the standalone-HM customs (T5.11)
# @directory: https://nix-community.github.io/home-manager/options.xhtml
#
# THE home-domain customs of platform/linux. Directory grammar v3 —
# directory-as-domain (T5.11): generic-Linux hosts run standalone HM
# only — no system form, hence NO default.nix at the platform top
# level (file absence = capability declaration: no system emitter
# ever asks for this platform). The whole platform directory IS the
# user domain: home/ and nothing else. mkHomeSystem imports
# platform/<tag>/home (a directory reference); this router then
# dispatches by arch into the payload rows — the SAME grammar
# platform/nixos/home/default.nix and platform/wsl/home/default.nix
# speak:
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
