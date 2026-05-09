# @path: ~/projects/configs/nix-config/tests/nixos/core/base/user.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::nixos::core::base::user
# @source: nixos/core/base/user.nix
#
# Mirrors production config:
#   users.mutableUsers = false
#   defaultUserShell = pkgs.zsh  (shared.user.shell = zsh)
#   extraGroups = [wheel networkmanager video libvirtd scanner lp input audio]
#   security.sudo.enable = true

{ pkgs, lib, ... }:
let
  testUser = "tester";
in
{
  name = "nixos_core_base_user";
  meta = { maintainers = [ "redskaber" ]; timeout = 120; };

  nodes.machine = {
    virtualisation.memorySize = 512;

    programs.zsh.enable = true;

    users = {
      mutableUsers    = false;
      defaultUserShell = pkgs.zsh;
      users.${testUser} = {
        isNormalUser    = true;
        useDefaultShell = true;
        description     = testUser;
        initialPassword = "nixtest";
        extraGroups     = [ "wheel" "networkmanager" "video" "audio" ];
      };
    };

    security.sudo.enable = true;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("user: exists in /etc/passwd"):
        out = machine.succeed("id ${testUser}").strip()
        assert "${testUser}" in out, f"User not found: {out}"

    with subtest("user: default shell is zsh"):
        shell = machine.succeed(
            "getent passwd ${testUser} | cut -d: -f7"
        ).strip()
        print(f"shell: {shell}")
        assert "zsh" in shell, f"Expected zsh, got: {shell}"

    with subtest("user: supplementary groups present"):
        grps = machine.succeed("id -Gn ${testUser}").strip()
        print(f"groups: {grps}")
        for g in ["wheel", "networkmanager", "video", "audio"]:
            assert g in grps, f"Missing group: {g}"

    with subtest("user: sudo binary present"):
        w = machine.succeed("which sudo").strip()
        assert "sudo" in w, f"sudo not found: {w}"

    with subtest("user: mutableUsers=false — useradd rejected"):
        rc = machine.execute("useradd __shouldfail__")[0]
        assert rc != 0, "useradd should fail when mutableUsers=false"
  '';
}
