# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/git-source.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: tests::home::core::exp::sys::base::git-source
# @source: home/core/exp/sys/base/git.nix
#
# T1.2 (production-tree import): asserts the REAL git/delta/lazygit module
# against its shared policy contract. Mutating the production module (a
# renamed policy key, a dropped alias, a scope flip on pkgs.lazygit) makes
# this check red at eval time — the mirror test home_*_git only checks
# installed binaries inside a VM and cannot see policy wiring drift.

{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # Minimal shared contract consumed by the production module.
  mockShared = {
    git = {
      defaultBranch = "mockmain";
      name = "mock-name";
      email = "mock@example.com";
      lazygit.name = "lg";
    };
    editor = {
      tag = "mockeditor";
    };
    # runtime-computed shellIntegrations contract (zsh user)
    shellIntegrations = {
      enableZshIntegration = true;
      enableFishIntegration = false;
      enableBashIntegration = false;
    };
  };

  # Marker package set — only the attrs the production module consumes.
  markPkgs = {
    lazygit = "STABLE:lazygit";
  };

  # ── REAL production import ────────────────────────────────────────
  production = import ../../../../../../home/core/exp/sys/base/git.nix {
    inherit inputs lib;
    shared = mockShared;
    config = { };
    pkgs = markPkgs; # daemon-scope markers for lazygit
  };

  git = production.programs.git;
  delta = production.programs.delta;
  lazygit = production.programs.lazygit;

  # ── Eval-time assertions ──────────────────────────────────────────
  evalAssertions =
    assert git.enable == true;
    # shared.git policy → git settings
    assert git.settings.init.defaultBranch == "mockmain";
    assert git.settings.user.name == "mock-name";
    assert git.settings.user.email == "mock@example.com";
    assert git.settings.core.editor == "mockeditor";
    # hard behavioural invariants
    assert git.settings.pull.rebase == true;
    assert git.settings.push.autoSetupRemote == true;
    assert builtins.elem ".direnv" git.ignores;
    # delta diff engine
    assert delta.enable == true;
    assert delta.enableGitIntegration == true;
    assert delta.options.side-by-side == true;
    assert delta.options.navigate == true;
    # lazygit: policy wrapper name + shell integrations + single-sourced pkg
    assert lazygit.enable == true;
    assert lazygit.shellWrapperName == "lg";
    assert lazygit.enableZshIntegration == true;
    assert lazygit.enableFishIntegration == false;
    assert lazygit.package == "STABLE:lazygit";
    assert lazygit.settings.git.merging.manualCommit == false;
    "eval-assertions-passed";
in
{
  name = "home_core_exp_sys_base_git_source";
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

    with subtest("git-source: production module evaluated, policy wiring intact"):
        # ${evalAssertions} — renders only if every policy reference in
        # home/core/exp/sys/base/git.nix still resolves as asserted.
        machine.succeed("true")
  '';
}
