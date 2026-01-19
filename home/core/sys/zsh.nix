# @path: ~/projects/configs/nix-config/home/core/sys/zsh.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::sys::zsh
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.zsh.enable
# @depends: eza, zoxide, direnv

{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
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
      # git alias
      g = "git";
      ga = "git add";
      gc = "git commit";
      gca = "git commit -a";
      gco = "git checkout";
      gst = "git status";
      gl = "git log --oneline";
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

    # Login-time welcome message
    initContent = ''
      # Welcome message (MOTD) for interactive shells
      if [[ -o interactive && $SHLVL -eq 1 && -z "$WELCOME_SHOWN" ]]; then
        export WELCOME_SHOWN=1
        if [[ $TERM != "dumb" ]]; then
          if command -v pokemon-colorscripts >/dev/null 2>&1 && command -v fastfetch >/dev/null 2>&1; then
            # Display Pokemon-colorscripts
            # Project page: https://gitlab.com/phoneybadger/pokemon-colorscripts#on-other-distros-and-macos
            #pokemon-colorscripts --no-title -s -r #without fastfetch
            pokemon-colorscripts --no-title -s -r | fastfetch -c "$HOME/.config/fastfetch/config-pokemon.jsonc" --logo-type file-raw --logo-height 10 --logo-width 5 --logo -
          elif command -v fastfetch >/dev/null 2>&1; then
            # fastfetch. Will be disabled if above colorscript was chosen to install
            fastfetch -c "$HOME/.config/fastfetch/config-compact.jsonc"
          fi
          echo
        fi
      fi
    '';

    # (non-nixos) dot zshenv configured
    # envExtra = ''
    #   # global rust cargo env (Hydrland ubuntu)
    #   . "$HOME/.cargo/env"
    # '';
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

