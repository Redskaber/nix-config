# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/fzf-source.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: tests::home::core::exp::sys::base::fzf-source
# @source: home/core/exp/sys/base/fzf.nix
#
# T1.2 (production-tree import): asserts the REAL fzf module — the
# shellIntegrations composition contract plus the widget/preview wiring
# that depends on eza/bat/fd being installed by sibling modules. The
# mirror test only checks the fzf binary; this check pins the option
# surface that makes Ctrl+T / Ctrl+R behave as designed.

{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # Minimal shared contract consumed by the production module.
  mockShared = {
    # runtime-computed shellIntegrations contract (zsh user)
    shellIntegrations = {
      enableZshIntegration = true;
      enableFishIntegration = false;
      enableBashIntegration = false;
    };
  };

  # ── REAL production import ────────────────────────────────────────
  production = import ../../../../../../home/core/exp/sys/base/fzf.nix {
    inherit inputs lib;
    shared = mockShared;
    config = { };
    pkgs = { }; # module consumes no packages
  };

  fzf = production.programs.fzf;

  # ── Eval-time assertions ──────────────────────────────────────────
  evalAssertions =
    assert fzf.enable == true;
    # shellIntegrations composition (zsh user)
    assert fzf.enableZshIntegration == true;
    assert fzf.enableFishIntegration == false;
    assert fzf.enableBashIntegration == false;
    # shared UI options for every widget
    assert builtins.elem "--layout=reverse" fzf.defaultOptions;
    assert builtins.elem "--cycle" fzf.defaultOptions;
    assert builtins.elem "--height=60%" fzf.defaultOptions;
    assert builtins.elem "--ansi" fzf.defaultOptions;
    assert builtins.elem "-i" fzf.defaultOptions;
    # Ctrl+T: directory/file previews delegate to eza/bat
    assert builtins.any (o: lib.hasInfix "--preview-window=right:60%:wrap" o) fzf.fileWidgetOptions;
    assert builtins.any (o: lib.hasInfix "eza --tree" o) fzf.fileWidgetOptions;
    assert builtins.any (o: lib.hasInfix "bat --style=numbers" o) fzf.fileWidgetOptions;
    # Ctrl+R: history prompt
    assert fzf.historyWidgetOptions == [ "--prompt='history> '" ];
    # file source / dir source = fd
    assert fzf.defaultCommand == "fd --hidden --strip-cwd-prefix --exclude .git";
    assert fzf.changeDirWidgetCommand == "fd --type=d --hidden --strip-cwd-prefix --exclude .git";
    assert builtins.any (o: lib.hasInfix "eza --tree" o) fzf.changeDirWidgetOptions;
    "eval-assertions-passed";
in
{
  name = "home_core_exp_sys_base_fzf_source";
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

    with subtest("fzf-source: production module evaluated, widget wiring intact"):
        # ${evalAssertions} — renders only if the fzf option surface
        # (integrations + preview delegates) is still as designed.
        machine.succeed("true")
  '';
}
