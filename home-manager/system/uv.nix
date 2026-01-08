# @path: ~/projects/nix-config/home-manager/system/uv.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.uv.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {

  programs.uv = {
    enable = true;
    settings = {
      pip = {
        index-url = "https://pypi.tuna.tsinghua.edu.cn/simple/";
        extra-index-url = [
          "https://pypi.org/simple/"
        ];
      };
      python-downloads = "never";
      python-preference = "only-system";
    }
  };
}
