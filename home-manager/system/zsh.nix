# @path: ~/projects/nix-config/home-manager/system/zsh.nix
# @author: redskaber
# @datetime: 2025-12-12
# @diractory: https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zsh.enable
# @depends: eza, zoxide, direnv

{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
# zsh env configuration
let
  zsh_path = "${config.home.profileDirectory}/bin/zsh";
in {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autocd = true;

    shellAliases = {
      ls = "eza --icons=always";
      ll = "eza -l --icons=always";
      la = "eza -la --icons=always";
      lt = "eza --tree --icons=always";
      j  = "z";
      # grep = "rg";  # ripgrep
      # cat = "bat";  # bat
      # top = "btm";  # bottom
      vi = "nvim";
      ".." = "cd ..";
      "..." = "cd ../..";
      "nde" =  "nvim ./.envrc";
    };

    history = {
      save = 10000;
      size = 10000;
      share = true;
      ignoreDups = true;
      ignoreSpace = true;
      ignorePatterns = [ "rm *" "pkill *" ":q" "exit" ];
      # save timestamp
      extended = true;
    };

    # history find configured
    historySubstringSearch.enable = true;
    historySubstringSearch.searchUpKey = [ "^[[A" "$terminfo[kcuu1]" ];
    historySubstringSearch.searchDownKey = [ "^[[B" "$terminfo[kcud1]" ];

    # command tips
    autosuggestion.enable = true;
    autosuggestion.strategy = [ "history" "completion" ];

    # syntax-highlight
    syntaxHighlighting.enable = true;
    syntaxHighlighting.highlighters = [ "main" "brackets" "pattern" "cursor" ];

    # default keymap (emacs)
    defaultKeymap = "emacs";

    # share session variable configured
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  home.activation.ensure_zsh_in_shells = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x ${zsh_path} ]; then
      if ! grep -Fxq '${zsh_path}' /etc/shells; then
        echo "⚠️ Zsh is installed but not in /etc/shells."
        echo "   To use 'chsh -s ${zsh_path}', run the following as root:"
        echo "     echo '${zsh_path}' | sudo tee -a /etc/shells"
        echo ""
      else
        verboseEcho "'${zsh_path}' already present in /etc/shells"
      fi
    else
      verboseEcho "Warning: ${zsh_path} not found - skipping /etc/shells check"
    fi
  '';
}


