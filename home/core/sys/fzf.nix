# @path: ~/projects/configs/nix-config/home/core/sys/fzf.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.fzf.enable


{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
    enableBashIntegration = false;
    enableFishIntegration = false;

    # Basic options for all fzf usage (including history search)
    defaultOptions = [
      "--margin=1"
      "--layout=reverse"
      "--border=none"
      "--info='hidden'"
      "-i"
      "--no-bold"
    ];

    # File-specific options via environment variables
    fileWidgetOptions = [
      "--preview='bat --style=numbers --color=always --line-range :500 {}'"
      "--preview-window=right:60%:wrap"
      "--preview 'if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi'"
    ];

    # History-specific options (keep it simple for Ctrl+R)
    historyWidgetOptions = [
      "--prompt='history> '"
    ];

    defaultCommand = "fd --hidden --strip-cwd-prefix --exclude .git";
    changeDirWidgetCommand = "fd --type=d --hidden --strip-cwd-prefix --exclude .git";
    changeDirWidgetOptions = [
      "--preview 'eza --tree --color=always {} | head -200'"
    ];

  };
}
