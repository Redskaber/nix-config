# @path: ~/projects/configs/nix-config/home/core/sys/compat.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: home::core::sys::compat


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{

  home.sessionVariables.WINEARCH = "win64";

  home.shellAliases = {
    # default
    # winenormal = "WINEPREFIX=~/.wine wine";

    # wechat
    # winewechat = "WINEPREFIX=~/.wine-wechat wine";
    # winewechat-init = "WINEPREFIX=~/.wine-wechat winetricks -q corefonts vcrun2019";

    # gaming
    winegames = "WINEPREFIX=~/.wine-games wine";
    winegames-init = "WINEPREFIX=~/.wine-games winetricks -q dxvk d3dcompiler_47";

    # tools
    winekill = "wineserver -k";
    winecfg-default = "winecfg";  # used ~/.wine

  };

}





