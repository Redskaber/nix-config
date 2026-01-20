# @path: ~/projects/configs/nix-config/home/hosts/nixos.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml


# This is your home-manager configuration file
# Use this to configure your home environment (it replace ~/.config/nixpkgs/home.nix)
{ inputs
, lib
, config
, pkgs
, ...
}:
{
  # You can import other home-manager modules here
  imports = [
    # If you import other home-manager modules from other flakes (such as nix-colors):
    # You can also split up your configuration and import pieces of it here:

    # hyprland handle shadow
    # ../core/srv/mako.nix

    ../core/sys/atuin.nix
    ../core/sys/bat.nix
    ../core/sys/bottom.nix
    ../core/sys/btop.nix
    ../core/sys/compat.nix
    ../core/sys/direnv.nix
    ../core/sys/fastfetch.nix
    ../core/sys/ffmpeg.nix
    ../core/sys/fish.nix
    ../core/sys/fonts.nix
    ../core/sys/fzf.nix
    ../core/sys/git.nix
    ../core/sys/htop.nix
    ../core/sys/starship.nix
    ../core/sys/wl-clipboard.nix
    ../core/sys/zoxide.nix
    ../core/sys/zsh.nix

    ../core/app/yazi
    ../core/app/baidupcs-go.nix
    ../core/app/cava.nix
    ../core/app/clash-verge-rev.nix
    ../core/app/discord.nix
    ../core/app/google-chrome.nix
    ../core/app/kitty.nix
    ../core/app/mpv.nix
    ../core/app/nemo.nix
    ../core/app/nvim.nix
    ../core/app/obsidian.nix
    ../core/app/qq.nix
    ../core/app/rbw.nix
    ../core/app/tealdeer.nix
    ../core/app/tmux.nix
    ../core/app/vscode.nix
    ../core/app/wechat.nix
    ../core/app/wezterm.nix
    ../core/app/zen-browser.nix
    ../core/app/game/minecraft.nix

    ../theme/qtct.nix
    ../theme/rofi.nix
    ../theme/satty.nix
    ../theme/swaylock.nix
    ../theme/swaync.nix
    ../theme/swayosd.nix
    ../theme/wallust.nix
    ../theme/waybar.nix
    ../theme/wlogout.nix


    ../wm/hyprland
    # devShells: import dev/lang.nix from flake.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      inputs.self.overlays.additions
      inputs.self.overlays.modifications
      inputs.self.overlays.unstable-packages


      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };

  # TODO: Set your username
  home = {
    username = "kilig";
    homeDirectory = "/home/kilig";
    stateVersion = "25.11";
  };

  # Add stuff for your user as you see fit:
  home.packages = with pkgs; [
    # network utils
    #   git bottom tree
        curl wget gnupg gdb
        valgrind strace ltrace pciutils vulkan-tools mesa
    # wm-backend
    #   wl-clipboard
    # Terminal shell
    #   wezterm (wrapper->nixgl) kitty (wrapper->nixgl)
    #   starship zsh fish
    # Tools
    #   bat fzf delta yazi
        ripgrep fd eza
    #   zoxide
    # Session
    #   tmux
    # Env auto-switching
    #   direnv nix-direnv
    # Fonts -> core::sys::fonts
    # Proxy
    #   clash-verge-rev
    # Social
    #   qq wechat mpv steam
    # Dev
    #   c/c++,rust,js/ts,python,lua,nix,...
    # Appimage runtime
        appimage-run
  ];

  # home-manager:
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}


