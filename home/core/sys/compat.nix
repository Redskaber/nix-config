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
    wine        = "WINEPREFIX=~/.wine/default wine";
    winecfg     = "WINEPREFIX=~/.wine/default winecfg";

    # app
    wineapp     = "WINEPREFIX=~/.wine/app wine";
    wineapp-init = "WINEPREFIX=~/.wine/app winetricks -q corefonts vcrun2019";

    # game
    winegame    = "WINEPREFIX=~/.wine/game wine";
    winegame-init = "WINEPREFIX=~/.wine/game winetricks -q dxvk d3dcompiler_47";

    # clear
    wineclear = ''
      echo "🧹 Clear Wine prefixes cache and temp files..." &&
      find ~/.wine -type d \( -name "cache" -o -name "Temp" -o -name "temp" -o -name "logs" \) -prune -exec sh -c 'rm -rf "{}"/* 2>/dev/null || true' \; &&
      echo "✅ Clear over"
    '';
  };

}



