# @path: ~/projects/configs/nix-config/home/core/exp/app/reader/z-library.nix
# @author: redskaber
# @datetime: 2026-06-14
# @description: home::core::exp::app::reader::z-library

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{
  # T3.2: sub-repo packages publish linux builds only — the
  # darwin closure skips this leaf (config-position mkIf).
  home.packages = lib.mkIf shared.caps.linux-family (
    with shared.upkgs;
    [
      inputs.z-library.packages.${shared.arch.tag}.default
    ]
  );

}
