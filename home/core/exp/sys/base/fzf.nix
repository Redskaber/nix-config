# @path: ~/projects/configs/nix-config/home/core/exp/sys/base/fzf.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::core::exp::sys::base::fzf
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.fzf.enable


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    enableFishIntegration = true;

    # Basic options for all fzf usage (including history search)
    defaultOptions = [
      "--margin=1"
      "--layout=reverse"
      "--border=rounded"
      "--info=inline-right"
      "--height=60%"
      "--ansi"
      "--cycle"
      "-i"
      "--no-bold"
    ];

    # File-specific options via environment variables
    # Ctrl+T
    fileWidgetOptions = [
      "--preview-window=right:60%:wrap"
      "--preview 'if [ -d {} ]; then eza --tree --level=2 --icons=always --color=always {} | head -200; else bat --style=numbers --color=always --line-range :300 {} 2>/dev/null; fi'"
    ];

    # History-specific options
    # Ctrl+R
    historyWidgetOptions = [
      "--prompt='history> '"
    ];

    defaultCommand = "fd --hidden --strip-cwd-prefix --exclude .git";
    changeDirWidgetCommand = "fd --type=d --hidden --strip-cwd-prefix --exclude .git";
    changeDirWidgetOptions = [
      "--preview 'eza --tree --level=2 --icons=always --color=always {} | head -200'"
    ];
  };
}
