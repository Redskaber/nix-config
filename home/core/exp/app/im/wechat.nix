# @path: ~/projects/configs/nix-config/home/core/exp/app/im/wechat.nix
# @author: redskaber
# @datetime: 2025-12-12

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
      inputs.wechat.packages.${shared.arch.tag}.default
    ]
  );

}
