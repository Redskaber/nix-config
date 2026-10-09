# @path: ~/projects/configs/nix-config/export/home/shell.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: export::home::shell — reusable zsh preset module
#
# Standalone, options-first distillation of home/core/exp/sys/shell/zsh.nix
# (the primary interactive shell preset): history contract, alias table,
# autosuggestion/syntax-highlighting, fzf-tab completion and the editor
# session variables — all tunable through options instead of `shared`.

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.redskaber.shell;
in
{
  options.redskaber.shell = {
    enable = lib.mkEnableOption "interactive zsh with the Kilig preset";

    editor = lib.mkOption {
      type = lib.types.str;
      default = "nvim";
      description = "Editor exported as EDITOR/VISUAL in interactive shells.";
    };

    historySize = lib.mkOption {
      type = lib.types.int;
      default = 50000;
      description = "History entries kept (in-memory and on disk).";
    };

    fzfTab = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the fzf-tab completion frontend (Tab menu rendered by fzf).";
    };

    extraAliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra shell aliases merged over the preset table.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autocd = true;
      defaultKeymap = "emacs";

      history = {
        path = "${config.xdg.dataHome}/zsh/zsh_history";
        size = cfg.historySize;
        save = cfg.historySize;
        share = true;
        ignoreDups = true;
        ignoreAllDups = true;
        saveNoDups = true;
        findNoDups = true;
        expireDuplicatesFirst = true;
        ignoreSpace = true;
        extended = true;
      };

      historySubstringSearch.enable = true;

      autosuggestion = {
        enable = true;
        strategy = [
          "history"
          "completion"
        ];
      };

      syntaxHighlighting.enable = true;

      shellAliases = {
        ls = "eza --icons=always";
        ll = "eza -l --icons=always";
        la = "eza -la --icons=always";
        lt = "eza --tree --icons=always";
        j = "z";
        vi = cfg.editor;
        vim = cfg.editor;
        ".." = "cd ..";
        "..." = "cd ../..";
        g = "git";
        gcm = "git commit -m";
        gst = "git status -sb";
        gl = "git log --oneline --graph --decorate";
        gd = "git diff";
        gp = "git push";
        gpl = "git pull --rebase";
      }
      // cfg.extraAliases;

      sessionVariables = {
        EDITOR = cfg.editor;
        VISUAL = cfg.editor;
        PAGER = "less -R";
        LESS = "-FRX";
      };

      plugins = lib.optionals cfg.fzfTab [
        {
          name = "fzf-tab";
          src = pkgs.zsh-fzf-tab;
        }
      ];

      completionInit = ''
        autoload -U compinit; compinit
        ${lib.optionalString cfg.fzfTab "source \${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh"}
        bindkey '^Xh' _complete_help

        zstyle ':completion:*' menu no
        zstyle ':completion:*' matcher-list \
          'm:{a-z}={A-Z}' \
          'r:|[._-]=* r:|=*' \
          'l:|=* r:|=*'
        zstyle ':completion:*' list-colors ''\${(s.:.)LS_COLORS}
        zstyle ':completion:*' group-name ""
        zstyle ':completion:*' use-cache yes
        zstyle ':completion:*' cache-path "${config.xdg.cacheHome}/zsh/zcompcache"
        zstyle ':completion:*:descriptions' format '[%d]'
      '';
    };
  };
}
