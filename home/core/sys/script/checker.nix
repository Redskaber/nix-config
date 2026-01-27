# @path: ~/projects/configs/nix-config/home/core/sys/script/checker.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::sys::script::checker
# - terminal-copy checker
# - A universal clipboard pipe script for terminal (Wayland/X11/macOS)


{ inputs
, lib
, config
, pkgs
, ...
}:
let
  terminal-copy-checker = pkgs.writeShellScriptBin "terminal-copy-checker" ''
    if command -v wl-copy >/dev/null; then
      exec wl-copy "$@"
    elif command -v xclip >/dev/null; then
      exec xclip -selection clipboard -i "$@"
    elif command -v xsel >/dev/null; then
      exec xsel --clipboard --input "$@"
    elif command -v pbcopy >/dev/null; then
      exec pbcopy "$@"
    else
      error_msg="terminal-copy: no clipboard utility found"
      hint_msg="Please install one of: wl-clipboard (Wayland), xclip/xsel (X11), or use macOS"

      if [ -n " $ {TMUX:-}" ]; then
          tmux display-message -d 4000 "❌  $error_msg"
      fi
      echo " $error_msg" >&2
      echo " $hint_msg" >&2
      exit 1
    fi
  '';
in
{
  home.packages = with pkgs; [ terminal-copy-checker ];
  # home.shellAliases = {
  #   terminal-copy-checker = terminal-copy-checker;
  # };

}


