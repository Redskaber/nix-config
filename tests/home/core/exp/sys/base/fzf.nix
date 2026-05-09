# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/fzf.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::exp::sys::base::fzf
# @source: home/core/exp/sys/base/fzf.nix

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_base_fzf";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [ fzf ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("fzf: binary present"):
        w = machine.succeed("which fzf").strip()
        assert "fzf" in w, f"fzf not found: {w}"

    with subtest("fzf: version reportable"):
        ver = machine.succeed("fzf --version 2>&1").strip()
        print(f"fzf: {ver}")
        assert ver != ""

    with subtest("fzf: filters input correctly"):
        out = machine.succeed(
            "printf 'alpha\nbeta\ngamma\n' | fzf --filter='bet' 2>/dev/null"
        ).strip()
        print(f"fzf filter: {out}")
        assert "beta" in out, f"fzf filter failed: {out}"
  '';
}
