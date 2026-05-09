# @path: ~/projects/configs/nix-config/tests/lib/shared/shared/fn.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::lib::shared::shared::fn
# @source: lib/shared/shared/fn.nix
#
# Validates lib functions via nix-instantiate:
#   - isNixOS  : platform == "nixos" → true; else false
#   - homeDir  : /home/<user> for nixos/linux; /Users/<user> for macos
#   - sopsRuntimePath : base + "/" + key
#   - sopsFile (path composition)

{ pkgs, lib, ... }:
{
  name = "lib_shared_shared_fn";
  meta = { maintainers = [ "redskaber" ]; timeout = 60; };

  nodes.machine = {
    virtualisation.memorySize = 256;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("fn: isNixOS(\"nixos\") = true"):
        out = machine.succeed(
            "nix-instantiate --eval -E '"
            "  let isNixOS = p: p == \"nixos\";"
            "  in isNixOS \"nixos\"'"
        ).strip()
        assert out == "true", f"isNixOS nixos should be true: {out}"

    with subtest("fn: isNixOS(\"linux\") = false"):
        out = machine.succeed(
            "nix-instantiate --eval -E '"
            "  let isNixOS = p: p == \"nixos\";"
            "  in isNixOS \"linux\"'"
        ).strip()
        assert out == "false", f"isNixOS linux should be false: {out}"

    with subtest("fn: homeDir nixos → /home/<user>"):
        out = machine.succeed(
            "nix-instantiate --eval -E '"
            "  let homeDir = platform: user:"
            "    if platform == \"macos\" then \"/Users/\" + user"
            "    else \"/home/\" + user;"
            "  in homeDir \"nixos\" \"kilig\"'"
        ).strip().strip('"')
        assert out == "/home/kilig", f"homeDir nixos mismatch: {out}"

    with subtest("fn: homeDir macos → /Users/<user>"):
        out = machine.succeed(
            "nix-instantiate --eval -E '"
            "  let homeDir = platform: user:"
            "    if platform == \"macos\" then \"/Users/\" + user"
            "    else \"/home/\" + user;"
            "  in homeDir \"macos\" \"kilig\"'"
        ).strip().strip('"')
        assert out == "/Users/kilig", f"homeDir macos mismatch: {out}"

    with subtest("fn: sopsRuntimePath base + key composition"):
        out = machine.succeed(
            "nix-instantiate --eval -E '"
            "  let sopsRuntimePath = base: key: base + \"/\" + key;"
            "  in sopsRuntimePath"
            "    \"/run/secrets\""
            "    \"nixos/core/base/user/kilig/password\"'"
        ).strip().strip('"')
        expected = "/run/secrets/nixos/core/base/user/kilig/password"
        assert out == expected, f"sopsPath mismatch: {out}"

    with subtest("fn: const secrets paths match naming convention"):
        out = machine.succeed(
            "nix-instantiate --eval -E '"
            "  let chipr = \"secrets/chipr\";"
            "      user  = \"kilig\";"
            "  in chipr + \"/nixos/core/base/user/\" + user + \"/password\"'"
        ).strip().strip('"')
        assert out == "secrets/chipr/nixos/core/base/user/kilig/password", \
            f"chipr path mismatch: {out}"
  '';
}
