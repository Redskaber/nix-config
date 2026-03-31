# @path: ~/projects/configs/nix-config/nixos/dm/ly/default.nix
# @author: redskaber
# @datetime: 2026-01-13
# @description: nixos::dm::ly::default


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  services.displayManager.ly = {
    enable = true;
    package = pkgs.ly;
    x11Support = true;
    settings = {
      animation = "matrix";
      bigclock = true;
      # --- Color Settings (0xAARRGGBB) ---
      # Background color of dialog box (Black)
      bg = "0x00000000";
      # Foreground text color (Cyan: #00FFFF)
      fg = "0x0000FFFF";
      # Border color (Red: #FF0000)
      border_fg = "0x00FF0000";
      # Error message color (Red)
      error_fg = "0x00FF0000";
      # Clock color (Purple: #800080)
      clock_color = "#800080";
    };
  };


}


