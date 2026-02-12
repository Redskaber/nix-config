# @path: ~/projects/configs/nix-config/home/core/sys/git.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::sys::git
# @diractory: https://nix-community.github.io/home/options.xhtml#opt-programs.git.enable


{ inputs
, lib
, config
, pkgs
, ...
}:
{
  programs.git = {
    enable = true;
    settings = {
      init = {
        defaultBranch = "main";
      };
      user = {
        name = "redskaber";
	      email = "redskaber@foxmail.com";
      };
      core.editor = "nvim";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
    ignores = [
      ".DS_Store"
      ".direnv"     # direnv
      ".cache"      # devShell
      ".venv"       # uv
      "*.swp"
      "*~"
    ];
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = true;
      true-color = "never";

      features = "unobtrusive-line-numbers decorations";
      unobtrusive-line-numbers = {
        line-numbers = true;
        line-numbers-left-format = "{nm:>4}│";
        line-numbers-right-format = "{np:>4}│";
        line-numbers-left-style = "grey";
        line-numbers-right-style = "grey";
      };
      decorations = {
        commit-decoration-style = "bold grey box ul";
        file-style = "bold blue";
        file-decoration-style = "ul";
        hunk-header-decoration-style = "box";
      };
    };
  };

  programs.lazygit = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    enableBashIntegration = true;

    settings = {
      gui = {
        theme = {
          lightTheme = false;
          activeBorderColor = [ "cyan" "bold" ];
          inactiveBorderColor = [ "240" ];  # 深灰色
          selectedLineBgColor = [ "236" ];  # 暗灰色背景
          optionsTextColor = [ "yellow" ];
        };
        scrollHeight = 2;
        scrollPastBottom = true;
        showListFooter = true;

        nerdFontsVersion = "3";               # 启用 Nerd Font 图标
        timeFormat = "02 Jan 06 15:04 MST";   # 人类可读时间格式
      };

      git = {
        paging = {
          colorArg = "always";
          useConfig = false;  # 优先使用 delta 配置
        };
        merging = {
          # 智能合并策略
          manualCommit = false;
          args = "-Xdiff-algorithm=histogram";
        };
        skipHookPrefix = "WIP";  # 跳过含此前缀的提交钩子
      };

      # 文件操作增强
      os = {
        editCommand = "nvim {filename}:{line}";  # 精确跳转到行号
        editCommandTemplate = "";
      };
    };
    shellWrapperName = "lg";  # 通过 `lg` 命令启动
    package = pkgs.lazygit;
  };


}


