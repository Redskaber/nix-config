# @path: ~/projects/configs/nix-config/tests/nmt/home/core/exp/sys/base/git.nix
# @author: redskaber
# @datetime: 2026-05-11
# @description: nmt::home::core::exp::sys::base::git
#
# nmt-Plane: dotfile content assertions (zero VM, pure eval, <10s)
#
# HM 25.11 git module:
#   - programs.git.userName/userEmail → written via pkgs.writeText or text string
#   - programs.git.extraConfig (attrset) → generates a pkgs.writeText derivation
#     SCRUBBED in nmt: content absent
#   - programs.delta → adds [delta] include to git config; delta is whitelisted
#
# Strategy: assert on userName/userEmail (which ARE in the main config text),
# skip extraConfig-derived keys (defaultBranch, rebase) as scrubbed.
# Use `programs.git.includes` or inline `extraConfig` as a plain string
# to inject testable content.
#
# In HM 25.11: programs.git.extraConfig accepts both attrset AND string.
# String form is written directly as text — NOT via a derivation.

{ lib, ... }:

lib.nmt.buildHomeManagerTest {
  description = "git: dotfile content assertions";

  modules = [{
    home = {
      username      = "testuser";
      homeDirectory = "/home/testuser";
      stateVersion  = "25.11";
    };

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
    };

    # delta is whitelisted → [delta] section written in git config
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
            optionsTextColor = [ "yellow" ];
          };
          scrollHeight = 2;
          scrollPastBottom = true;
          showListFooter = true;
        };

        git = {
          merging = {
            manualCommit = false;
          };
        };

        os = {
          editCommandTemplate = "";
        };
      };
    };

  }];

  tests = {
    "git: config file exists" = {
      path   = ".config/git/config";
      exists = true;
    };

    "git: user.name written" = {
      path     = ".config/git/config";
      contains = [ "name = \"redskaber\"" ];
    };

    "git: user.email written" = {
      path     = ".config/git/config";
      contains = [ "email = \"redskaber@foxmail.com\"" ];
    };

    # String extraConfig is plain text — always present
    "git: defaultBranch = main" = {
      path     = ".config/git/config";
      contains = [ "defaultBranch = \"main\"" ];
    };

    "git: pull.rebase = true" = {
      path     = ".config/git/config";
      contains = [ "rebase = true" ];
    };

    # programs.delta adds [delta] section; delta is whitelisted
    "git: delta section present" = {
      path     = ".config/git/config";
      contains = [ "[delta]" ];
    };

    # lazygit config uses pkgs.formats.yaml — exists as symlink
    "git: lazygit config symlink present" = {
      path   = ".config/lazygit/config.yml";
      exists = true;
    };
  };
}
