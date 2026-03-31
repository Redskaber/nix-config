# @path: ~/projects/configs/nix-config/home/core/sys/zsh.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::sys::zsh
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.zsh.enable
# @depends: eza, zoxide, direnv, fzf

{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
let
  zsh_path = "${config.home.profileDirectory}/bin/zsh";
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autocd = true;

    # default keymap (emacs)
    defaultKeymap = "emacs";

    setOptions = [
      # history
      "APPEND_HISTORY"
      "EXTENDED_HISTORY"
      "HIST_EXPIRE_DUPS_FIRST"
      "HIST_FIND_NO_DUPS"
      "HIST_IGNORE_ALL_DUPS"
      "HIST_IGNORE_DUPS"
      "HIST_IGNORE_SPACE"
      "HIST_SAVE_NO_DUPS"
      "HIST_REDUCE_BLANKS"
      "SHARE_HISTORY"

      # navigation / UX
      "AUTO_CD"
      "AUTO_PUSHD"
      "PUSHD_IGNORE_DUPS"
      "PUSHD_SILENT"
      "INTERACTIVE_COMMENTS"

      # completion
      "COMPLETE_IN_WORD"
      "ALWAYS_TO_END"
      "AUTO_MENU"

      # safety / quiet
      "NO_BEEP"
    ];

    shellAliases = {
      ls = "eza --icons=always";
      ll = "eza -l --icons=always";
      la = "eza -la --icons=always";
      lt = "eza --tree --icons=always";
      j  = "z";
      # Optional modern replacements
      # grep = "rg";
      # cat = "bat --paging=never";
      # top = "btm";
      vi = "nvim";
      vim = "nvim";
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "nde" =  "nvim ./.envrc";
      # git aliases
      g = "git";
      ga = "git add";
      gaa = "git add --all";
      gc = "git commit";
      gca = "git commit -a";
      gcm = "git commit -m";
      gco = "git checkout";
      gcb = "git checkout -b";
      gst = "git status -sb";
      gl = "git log --oneline --graph --decorate";
      gd = "git diff";
      gds = "git diff --staged";
      gp = "git push";
      gpl = "git pull --rebase";
    };

    shellGlobalAliases = {
      G = "| grep";
      R = "| rg";
      L = "| less";
      H = "| head";
      T = "| tail";
      C = "| wc -l";
      J = "| jq";
    };

    history = {
      path = "${config.xdg.dataHome}/zsh/zsh_history";
      save = 50000;
      size = 50000;
      share = true;
      append = true;
      ignoreDups = true;
      ignoreAllDups = true;
      saveNoDups = true;
      findNoDups = true;
      expireDuplicatesFirst = true;
      ignoreSpace = true;
      extended = true;
      ignorePatterns = [
        "rm *"
        "pkill *"
        ":q"
        "exit"
        "clear"
        "history"
        "pwd"
      ];
    };

    # history find configured
    historySubstringSearch.enable = true;
    historySubstringSearch.searchUpKey = [ "^[[A" "$terminfo[kcuu1]" ];
    historySubstringSearch.searchDownKey = [ "^[[B" "$terminfo[kcud1]" ];

    # command tips
    autosuggestion = {
      enable = true;
      strategy = [ "history" "completion" ];
      highlight = "fg=#7c6f64";
    };

    # syntax-highlight
    syntaxHighlighting = {
      enable = true;
      highlighters = [ "main" "brackets" "pattern" "cursor" ];
      patterns = {
        "rm -rf *" = "fg=white,bold,bg=red";
        "sudo rm -rf *" = "fg=white,bold,bg=red";
      };
      styles = {
        comment = "fg=8";
        alias = "fg=cyan";
        path = "underline";
      };
    };

    # share session variable configured
    sessionVariables = {
      EDITOR = shared.editor.tag;
      VISUAL = shared.editor.tag;
      PAGER = "less -R";
      LESS = "-FRX";
    };

    # autoload function
    siteFunctions = {
      mkcd = ''
        mkdir -p -- "$1" && cd -- "$1"
      '';
      take = ''
        mkdir -p -- "$1" && cd -- "$1"
      '';
    };

    plugins = [
      {
        name = "fzf-tab";
        src = pkgs.zsh-fzf-tab;
      }
    ];

    completionInit = ''
      # ------------------------------------------------------------
      # fzf-tab load
      # ------------------------------------------------------------
      autoload -U compinit; compinit
      source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
      bindkey '^Xh' _complete_help

      # ------------------------------------------------------------
      # Zsh completion styles
      # ------------------------------------------------------------
      # 基础 completion 行为
      zstyle ':completion:*' menu no
      zstyle ':completion:*' matcher-list \
        'm:{a-z}={A-Z}' \
        'r:|[._-]=* r:|=*' \
        'l:|=* r:|=*'
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
      zstyle ':completion:*' group-name ""
      zstyle ':completion:*' verbose yes
      zstyle ':completion:*' use-cache yes
      zstyle ':completion:*' cache-path "${config.xdg.cacheHome}/zsh/zcompcache"

      # 显示分组标题
      zstyle ':completion:*:descriptions' format '[%d]'
      zstyle ':completion:*:warnings' format '[no matches for: %d]'
      zstyle ':completion:*:messages' format '[%d]'
      zstyle ':completion:*:corrections' format '[%d (%e errors)]'

      # 目录跳转
      zstyle ':completion:*' squeeze-slashes true
      zstyle ':completion:*' special-dirs true

      # 补全排序
      zstyle ':completion:*:git-checkout:*' sort false
      zstyle ':completion:*:git-switch:*' sort false

      # 进程补全
      zstyle ':completion:*:*:*:*:processes' command \
        'ps -u $USER -o pid,ppid,stat,%cpu,%mem,etime,command -w -w'

      # ------------------------------------------------------------
      # fzf-tab styles
      # ------------------------------------------------------------
      # tmux，可改成 ftb-tmux-popup
      # zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
      # zstyle ':fzf-tab:*' popup-min-size 82 24
      # zstyle ':fzf-tab:*' popup-smart-tab yes
      zstyle ':fzf-tab:*' fzf-command fzf

      # 捕捉并展示 zsh completion
      zstyle ':fzf-tab:*' disabled-on none

      # 分组显示：完整显示组名
      zstyle ':fzf-tab:*' show-group full
      zstyle ':fzf-tab:*' switch-group '<' '>'
      # 也可以保留默认 F1/F2，二选一：
      # zstyle ':fzf-tab:*' switch-group F1 F2

      # 单组时也保留 header / color
      zstyle ':fzf-tab:*' single-group color header

      # 查询策略：优先 prefix，再用 input
      zstyle ':fzf-tab:*' query-string prefix input first

      # 连续补全：深路径
      zstyle ':fzf-tab:*' continuous-trigger '/'

      # 用户当前输入作为结果输出（可选）
      zstyle ':fzf-tab:*' print-query alt-enter

      # fzf-tab 不默认继承 FZF_DEFAULT_OPTS，建议显式配置，不建议开 use-fzf-default-opts
      zstyle ':fzf-tab:*' use-fzf-default-opts no

      # fzf 面板高度修正
      zstyle ':fzf-tab:*' fzf-pad 2
      zstyle ':fzf-tab:*' fzf-min-height 12

      # fzf-tab 专用 flags
      zstyle ':fzf-tab:*' fzf-flags \
        --height=60% \
        --layout=reverse \
        --border=rounded \
        --info=inline-right \
        --prompt='❯ ' \
        --pointer='▶' \
        --marker='✓' \
        --ansi \
        --cycle

      # 常用按键
      zstyle ':fzf-tab:*' fzf-bindings \
        'tab:accept' \
        'shift-tab:up' \
        'ctrl-j:down' \
        'ctrl-k:up' \
        'ctrl-space:toggle+down' \
        'ctrl-a:select-all' \
        'ctrl-d:half-page-down' \
        'ctrl-u:half-page-up' \
        'alt-j:preview-down' \
        'alt-k:preview-up'

      # Space 接受并直接执行
      # 如果你想更激进可以启用：
      # zstyle ':fzf-tab:*' accept-line enter

      # ------------------------------------------------------------
      # Smart previews
      # ------------------------------------------------------------
      # cd: 目录树预览
      zstyle ':fzf-tab:complete:cd:*' fzf-preview \
        'eza --tree --level=2 --icons=always --color=always $realpath 2>/dev/null | head -200'

      # zoxide/z 跳转
      zstyle ':fzf-tab:complete:_zoxide_z:*' query-string input
      zstyle ':fzf-tab:complete:_zoxide_z:*' fzf-preview \
        'eza --tree --level=2 --icons=always --color=always $realpath 2>/dev/null | head -200'

      # export / unset / typeset
      zstyle ':fzf-tab:complete:(export|unset|typeset|declare|local):*' fzf-preview \
        'print -r -- ''${(P)word} 2>/dev/null'

      # ssh known_hosts
      zstyle ':fzf-tab:complete:ssh:*' fzf-preview \
        'dig +short $word 2>/dev/null; getent hosts $word 2>/dev/null'

      # kill 进程预览
      zstyle ':fzf-tab:complete:kill:*' fzf-preview \
        'ps -p $word -o pid,ppid,user,%cpu,%mem,etime,command -ww'

      # man 章节 / 命令类
      zstyle ':fzf-tab:complete:man:*' fzf-preview \
        'MANWIDTH=$((COLUMNS/2)) man $word 2>/dev/null | col -bx | head -200'

      # git checkout / switch 分支预览
      zstyle ':fzf-tab:complete:git-(checkout|switch):*' fzf-preview \
        'git log --oneline --decorate --color=always -n 30 $word 2>/dev/null'

      # git add / restore / diff 文件预览
      zstyle ':fzf-tab:complete:git-(add|restore|diff):*' fzf-preview \
        'if [ -d $realpath ]; then eza --tree --icons=always --color=always $realpath | head -200; else bat --style=numbers --color=always --line-range :300 $realpath 2>/dev/null; fi'

      # 通用文件预览（兜底）
      zstyle ':fzf-tab:complete:*:*' fzf-preview \
        'if [ -d $realpath ]; then eza --tree --level=2 --icons=always --color=always $realpath 2>/dev/null | head -200; elif [ -f $realpath ]; then bat --style=numbers --color=always --line-range :300 $realpath 2>/dev/null; fi'
    '';

    # Main-config
    initContent = ''
      # ------------------------------------------------------------
      # Welcome message (MOTD) for interactive shells
      # ------------------------------------------------------------
      # if [[ -o interactive && $SHLVL -eq 1 && -z "$WELCOME_SHOWN" ]]; then
      #   export WELCOME_SHOWN=1
      #   if [[ $TERM != "dumb" ]]; then
      #     if command -v pokemon-colorscripts >/dev/null 2>&1 && command -v fastfetch >/dev/null 2>&1; then
      #       pokemon-colorscripts --no-title -s -r | fastfetch -c "$HOME/.config/fastfetch/config-pokemon.jsonc" --logo-type file-raw --logo-height 10 --logo-width 5 --logo -
      #     elif command -v fastfetch >/dev/null 2>&1; then
      #       fastfetch -c "$HOME/.config/fastfetch/config-compact.jsonc"
      #     fi
      #     echo
      #   fi
      # fi
    '';
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

