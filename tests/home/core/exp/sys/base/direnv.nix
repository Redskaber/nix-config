# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/direnv.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::exp::sys::base::direnv
# @source: home/core/exp/sys/base/direnv.nix
#
# Mirrors production:
#   programs.direnv.enable = true
#   nix-direnv.enable = true
#   enableBashIntegration = true
#   enableZshIntegration = true

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_base_direnv";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    environment.systemPackages = with pkgs; [ direnv nix-direnv ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("direnv: binary present"):
        ver = machine.succeed("direnv version 2>&1").strip()
        print(f"direnv: {ver}")
        assert ver != "", "direnv version empty"

    with subtest("direnv: allow + export works"):
        machine.succeed("""
          mkdir -p /tmp/direnv_test
          echo 'export DIRENV_TEST_VAR=hello_direnv' > /tmp/direnv_test/.envrc
          cd /tmp/direnv_test
          direnv allow .
          eval "$(cd /tmp/direnv_test && direnv export bash)"
          [ "$DIRENV_TEST_VAR" = "hello_direnv" ] || exit 1
        """)
  '';
}
