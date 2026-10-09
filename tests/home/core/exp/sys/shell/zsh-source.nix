# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/shell/zsh-source.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: tests::home::core::exp::sys::shell::zsh-source
# @source: home/core/exp/sys/shell/zsh.nix
#
# T1.2 (production-tree import): asserts the REAL zsh module — the
# primary interactive shell (shared.user.shell.tag == "zsh"). This is
# the heaviest production module of the five T1.2 samples: it consumes
# config.home.homeDirectory / config.xdg.{dataHome,cacheHome} (module
# system references), shared.editor.tag and a package (zsh-fzf-tab).
# The mirror test boots a VM and sources /etc/zshrc; this check instead
# pins the option surface — history contract, alias table, fzf-tab
# plugin wiring and completion init — at eval time.

{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # Minimal module-system config contract consumed by the production module.
  mockConfig = {
    home = {
      homeDirectory = "/home/mockuser";
    };
    xdg = {
      dataHome = "/home/mockuser/.local/share";
      cacheHome = "/home/mockuser/.cache";
    };
  };

  # Minimal shared contract consumed by the production module.
  mockShared = {
    editor = {
      tag = "mockeditor";
    };
  };

  # Marker package set — only the attrs the production module consumes.
  markPkgs = {
    zsh-fzf-tab = "STABLE:zsh-fzf-tab";
  };

  # ── REAL production import ────────────────────────────────────────
  production = import ../../../../../../home/core/exp/sys/shell/zsh.nix {
    inherit inputs lib;
    shared = mockShared;
    config = mockConfig;
    pkgs = markPkgs;
  };

  zsh = production.programs.zsh;
  fzfTabPlugin = builtins.elemAt zsh.plugins 0;

  # ── Eval-time assertions ──────────────────────────────────────────
  evalAssertions =
    assert zsh.enable == true;
    assert zsh.enableCompletion == true;
    assert zsh.autocd == true;
    assert zsh.defaultKeymap == "emacs";
    # ZDOTDIR + history under XDG (config.* references resolved)
    assert production.home.sessionVariables.ZDOTDIR == "/home/mockuser/.config/zsh";
    assert zsh.history.path == "/home/mockuser/.local/share/zsh/zsh_history";
    assert zsh.history.size == 50000 && zsh.history.save == 50000;
    assert zsh.history.share == true;
    # alias table (eza delegation + git shortcuts)
    assert zsh.shellAliases.ls == "eza --icons=always";
    assert zsh.shellAliases.ll == "eza -l --icons=always";
    assert zsh.shellAliases.j == "z";
    assert zsh.shellAliases.vi == "nvim";
    assert zsh.shellAliases.gcm == "git commit -m";
    # global pipe aliases
    assert zsh.shellGlobalAliases.R == "| rg";
    assert zsh.shellGlobalAliases.J == "| jq";
    # editor policy propagation
    assert zsh.sessionVariables.EDITOR == "mockeditor";
    assert zsh.sessionVariables.VISUAL == "mockeditor";
    # interactive sugar
    assert zsh.autosuggestion.enable == true;
    assert
      zsh.autosuggestion.strategy == [
        "history"
        "completion"
      ];
    assert zsh.syntaxHighlighting.enable == true;
    # fzf-tab plugin comes from the daemon scope (marker)
    assert builtins.length zsh.plugins == 1;
    assert fzfTabPlugin.name == "fzf-tab";
    assert fzfTabPlugin.src == "STABLE:zsh-fzf-tab";
    # completion init: compinit + fzf-tab + zcompcache under XDG
    assert builtins.match ".*autoload -U compinit; compinit.*" zsh.completionInit != null;
    assert builtins.match ".*fzf-tab.plugin.zsh.*" zsh.completionInit != null;
    assert builtins.match ".*/zsh/zcompcache.*" zsh.completionInit != null;
    "eval-assertions-passed";
in
{
  name = "home_core_exp_sys_shell_zsh_source";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 60;
  };

  nodes.machine = {
    virtualisation.memorySize = 256;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("zsh-source: production module evaluated, shell contract intact"):
        # ${evalAssertions} — renders only if the whole zsh option
        # surface still matches the designed contract.
        machine.succeed("true")
  '';
}
