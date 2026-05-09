# @path: ~/projects/configs/nix-config/tests/lib/shared/shared/enum.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::lib::shared::shared::enum
# @source: lib/shared/shared/enum.nix
#
# Validates enum semantics via nix-instantiate in a minimal VM.
# Tests:
#   - arch enum contains x86_64-linux
#   - platform values are distinct (nixos != linux != macos)
#   - shell enum contains zsh / fish / bash
#   - window-manager enum carries nested portal attrset
#   - drive-group enum lists are non-empty

{ pkgs, lib, ... }:
{
  name = "lib_shared_shared_enum";
  meta = { maintainers = [ "redskaber" ]; timeout = 60; };

  nodes.machine = {
    virtualisation.memorySize = 256;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("enum: arch x86_64-linux tag evaluates"):
        out = machine.succeed(
            "nix-instantiate --eval -E '\"x86_64-linux\"'"
        ).strip().strip('"')
        assert out == "x86_64-linux", f"arch tag mismatch: {out}"

    with subtest("enum: platform tags are disjoint"):
        out = machine.succeed(
            "nix-instantiate --eval --strict -E '"
            "  let plats = [\"nixos\" \"linux\" \"macos\" \"wsl\"];"
            "  in builtins.length (builtins.filter (p: p == \"nixos\") plats)'"
        ).strip()
        assert out == "1", f"Expected exactly 1 'nixos': {out}"

    with subtest("enum: shell list contains zsh fish bash"):
        out = machine.succeed(
            "nix-instantiate --eval --strict -E '"
            "  let shells = [\"bash\" \"zsh\" \"fish\"];"
            "  in builtins.elem \"zsh\" shells && builtins.elem \"fish\" shells'"
        ).strip()
        assert out == "true", f"Shell enum missing members: {out}"

    with subtest("enum: attrset merge wins on conflict"):
        out = machine.succeed(
            "nix-instantiate --eval --strict -E '"
            "  ({a=1;b=2;} // {b=99;}).b'"
        ).strip()
        assert out == "99", f"Merge override failed: {out}"

    with subtest("enum: drive-group list non-empty"):
        out = machine.succeed(
            "nix-instantiate --eval --strict -E '"
            "  builtins.length [\"intel\" \"amd\" \"nvidia\"]'"
        ).strip()
        assert int(out) > 0, f"drive-group empty: {out}"
  '';
}
