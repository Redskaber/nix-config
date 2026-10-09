# @path: ~/projects/configs/nix-config/tests/lib/shared/lang/fn.nix
# @author: redskaber
# @datetime: 2026-10-08
# @description: tests::lib::shared::lang::fn
# @source: lib/shared/lang/fn.nix
#
# T1.1 (test-truthfulness): asserts run against the REAL production
# sources — lib/shared/lang/{enum,const,fn}.nix are imported and
# evaluated at CHECK-BUILD time. If any production function regresses,
# evaluation fails before a VM ever boots.
#
# T4.0 (dispatch-layer convergence): the isNixOS/isLinux/isMacOS/isWSL
# tag-comparison predicates are GONE from fn.nix — platform semantics
# live in the enum.nix dispatch table now, and this test asserts the
# new contract instead of the old predicates:
#
#   - fn.homeDir: pure interpolation over the platform table's
#     home-prefix payload (no branching to mutate into a lie)
#   - enum instance shape for multi-select groups (tag + value list)
#   - sameSource: the dual-source governance guard still throws on
#     mixed fingerprint scopes (the 995d8c9 class)
#
# The capability-table contract itself (caps vectors, strategy
# lambdas, Null-Object rows) lives in caps.nix beside this file.

{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # ── REAL production imports (no mocks, no copies) ─────────────────
  realEnum = import ../../../../lib/shared/lang/enum.nix { inherit inputs; };
  realConst = import ../../../../lib/shared/lang/const.nix;
  realFn = import ../../../../lib/shared/lang/fn.nix { };

  dg = realEnum.drive-group.amd-nvidia;

  # Marker scopes for the sameSource guard (T2.6): distinct
  # lib.trivial.version fingerprints stand in for stable/unstable.
  stableScope = {
    lib.trivial.version = "26.05";
  };
  unstableScope = {
    lib.trivial.version = "26.11pre-mock";
  };

  # ── Eval-time assertions (fail the check build, not just the VM) ──
  evalAssertions =
    # homeDir: data-driven via the platform table's home-prefix row —
    # each platform answers for itself, no branch can drift.
    assert realFn.homeDir realEnum.platform.darwin "kilig" == "/Users/kilig";
    assert realFn.homeDir realEnum.platform.nixos "kilig" == "/home/kilig";
    assert realFn.homeDir realEnum.platform.linux "kilig" == "/home/kilig";
    assert realFn.homeDir realEnum.platform.wsl "kilig" == "/home/kilig";
    # the prefix is payload data, asserted per row (mutation target)
    assert realEnum.platform.darwin.value.home-prefix == "/Users";
    assert realEnum.platform.nixos.value.home-prefix == "/home";
    # predicates are truly gone: the dispatch table owns platform facts
    assert !(realFn ? isNixOS) && !(realFn ? isMacOS) && !(realFn ? isWSL) && !(realFn ? isLinux);
    assert
      realFn.sopsFile "/self" realConst.secrets.chipr "user/kilig/password"
      == "/self/secrets/chipr/user/kilig/password.yaml";
    assert realFn.sopsRuntimePath "/run/secrets" "db/pg" == "/run/secrets/db/pg";
    # sameSource: matching fingerprints pass through, mismatched throw
    assert realFn.sameSource "test" stableScope stableScope == stableScope;
    assert !(builtins.tryEval (realFn.sameSource "test" stableScope unstableScope)).success;
    assert dg ? tag && dg.tag == "amd-nvidia";
    assert builtins.isList dg.value && builtins.length dg.value == 2;
    "eval-assertions-passed";
in
{
  name = "lib_shared_lang_fn";
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

    with subtest("fn: production sources evaluated with all assertions"):
        # The heavy lifting happened at evaluation time (${evalAssertions});
        # the VM only proves the check boots.
        machine.succeed("true")
  '';
}
