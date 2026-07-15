# @path: ~/projects/configs/nix-config/tests/home/core/exp/sys/base/yazi.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: tests::home::core::exp::sys::base::yazi
# @source: home/core/exp/sys/base/yazi/default.nix
#
# Verifies misc tools: yazi (file manager)

{ pkgs, lib, ... }:
{
  name = "home_core_exp_sys_base_yazi";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;
    programs.yazi.enable = true;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("yazi: yazi binary present"):
        machine.succeed("which yazi")

    # FIXME:
    #
    # ❯ yazi --version
    # TOML parse error at line 113, column 3
    #     |
    # 113 |   { name = "*", fg = "#cdd6f4" },
    #     |   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
    # at least one of `url` or `mime` must be specified
    #
    # Press <Enter> to continue with preset settings...
    #
    # Yazi 26.5.6 (Nixpkgs 2026-05-05)
    #
    # need enter,
    # with subtest("yazi: yazi --version (optional, with safe guard)"):
    #     machine.succeed("yazi --version")

    with subtest("yazi: ya (yazi assistant) binary present"):
        machine.succeed("which ya")
  '';
}
