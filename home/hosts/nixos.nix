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
  # linux non-nixos environment inject
  targets.genericLinux = {
    enable = true;
    nixGL = {
      packages = inputs.nixgl.packages;
      defaultWrapper = "mesa";
      offloadWrapper = "mesaPrime";
    };
  };

  # You can import other home-manager modules here
  imports = [
    # If you import other home-manager modules from other flakes (such as nix-colors):
    # You can also split up your configuration and import pieces of it here:
    ../wm/hyprland

    ../core/srv/mako.nix

    ../core/sys/atuin.nix
    ../core/sys/bat.nix
    ../core/sys/bottom.nix
    ../core/sys/btop.nix
    ../core/sys/direnv.nix
    ../core/sys/fastfetch.nix
    ../core/sys/fish.nix
    ../core/sys/fonts.nix
    ../core/sys/fzf.nix
    ../core/sys/git.nix
    ../core/sys/htop.nix
    ../core/sys/starship.nix
    ../core/sys/uv.nix
    ../core/sys/wl-clipboard.nix
    ../core/sys/zoxide.nix
    ../core/sys/zsh.nix

    ../core/app/ghostty
    ../core/app/yazi
    ../core/app/cava.nix
    ../core/app/discord.nix
    ../core/app/google-chrome.nix
    ../core/app/kitty.nix
    ../core/app/mpv.nix
    ../core/app/nemo.nix
    ../core/app/nh.nix
    ../core/app/nvim.nix
    ../core/app/obsidian.nix
    ../core/app/qq.nix
    ../core/app/quickshell.nix
    ../core/app/rbw.nix
    ../core/app/rofi.nix
    ../core/app/rustdesk.nix
    ../core/app/steam.nix
    ../core/app/swaylock.nix
    ../core/app/swaync.nix
    ../core/app/swayosd.nix
    ../core/app/tealdeer.nix
    ../core/app/tmux.nix
    ../core/app/vscode.nix
    ../core/app/waybar.nix
    ../core/app/wechat.nix
    ../core/app/wezterm.nix
    ../core/app/zen-browser.nix

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
    curl wget gnupg git bottom tree
    gdb valgrind strace ltrace pciutils
    # wm-backend
    # wl-clipboard
    # Terminal prompt shell
    # wezterm (wrapper->nixgl) kitty (wrapper->nixgl)
    starship zsh fish
    # find and tools
    # bat fzf delta yazi
    ripgrep fd eza zoxide
    # session
    tmux
    # env auto-switching
    direnv nix-direnv
    # fonts -> core::sys::fonts
    # proxy
    clash-verge-rev
    # social
    # qq wechat mpv steam
    # dev
    # c/c++,rust,js/ts,python,lua,nix,...
    appimage-run
  ];

  # home-manager:
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}


