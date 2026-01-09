# @path: ~/projects/configs/nix-config/home-manager/system/atuin.nix
# @author: redskaber
# @datetime: 2026-01-10
# @description: Atuin — Magical shell history with sync, search & stats
# @reference: https://docs.atuin.sh


{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.atuin = {
    enable = true;

    # === Shell integrations ===
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    # Nushell not used in your setup → leave disabled

    # === Recommended settings for modern workflow ===
    settings = {
      # Search behavior
      search_mode = "fuzzy";
      filter_mode = "host";  # Only show history from this machine
      style = "compact";     # Clean UI that fits small terminals

      # Sync (opt-in via `atuin login`)
      auto_sync = true;
      sync_frequency = "10m";
      update_check = false;  # Disable update nag (you manage via Nix)

      # UI/UX
      show_preview = true;
      preview_height = 4;
      show_help = true;
      invert = false;

      # Keymap (auto-detect based on shell)
      keymap_mode = "auto";

      # Cursor styling per mode (requires terminal support)
      keymap_cursor = {
        emacs = "blink-block";
        vim_insert = "blink-block";
        vim_normal = "steady-block";
      };
    };

    # Force overwrite on first deploy to avoid Atuin's auto-generated config conflict
    forceOverwriteSettings = true;

    # === Theming: use built-in 'marine' for a clean, modern look ===
    # You can later create ～/.config/atuin/themes/my-theme.toml if desired
    themes = {
      marine = {
        theme.name = "marine";
        parent = "marine";
        colors = {
          Base = "#e0e0e0";
          Title = "#8be9fd";
          Annotation = "#6272a4";
          Guidance = "#50fa7b";
          Important = "#ff79c6";
          AlertInfo = "#8be9fd";
          AlertWarn = "#f1fa8c";
          AlertError = "#ff5555";
        };
      };
    };

    # Optional: uncomment to enable daemon (requires Atuin >=18.2)
    # daemon = {
    #   enable = true;
    #   logLevel = "info";
    # };
  };
}


