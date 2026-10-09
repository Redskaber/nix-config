# @path: ~/projects/configs/nix-config/home/core/exp/app/editor/zcode.nix
# @author: redskaber
# @datetime: 2026-08-04
# @discription: home::core::exp::app::editor::zcode

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
      inputs.zcode.packages.${shared.arch.tag}.default
    ]
  );

}
