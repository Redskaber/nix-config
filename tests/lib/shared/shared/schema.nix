# @path: ~/projects/configs/nix-config/tests/lib/shared/shared/schema.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::lib::shared::shared::schema
# @source: lib/shared/shared/schema.nix
#
# Validates shared schema structure:
#   - Required top-level keys (arch, platform, user, hostName)
#   - Nested user.username accessible
#   - Merge semantics: base // overlay → overlay wins
#   - Runtime merge order: shared ← user_shared ← runtime fields

{ pkgs, lib, ... }:
{
  name = "lib_shared_shared_schema";
  meta = { maintainers = [ "redskaber" ]; timeout = 60; };

  nodes.machine = {
    virtualisation.memorySize = 256;
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("schema: valid attrset user.username accessible"):
        out = machine.succeed(
            "nix-instantiate --eval --strict -E '"
            "  let s = {"
            "    arch     = { tag = \"x86_64-linux\"; };"
            "    platform = { tag = \"nixos\"; };"
            "    user     = { username = \"kilig\"; shell = { tag = \"zsh\"; }; openssh-authKeys = []; };"
            "    hostName = \"nixos\";"
            "  };"
            "  in s.user.username'"
        ).strip().strip('"')
        assert out == "kilig", f"Expected kilig, got: {out}"

    with subtest("schema: arch.tag accessible"):
        out = machine.succeed(
            "nix-instantiate --eval -E '"
            "  ({ tag = \"x86_64-linux\"; }).tag'"
        ).strip().strip('"')
        assert out == "x86_64-linux", f"arch.tag mismatch: {out}"

    with subtest("schema: merge semantics — later keys win"):
        out = machine.succeed(
            "nix-instantiate --eval --strict -E '"
            "  let base    = { a = 1; b = 2; c = 3; };"
            "      overlay = { b = 99; d = 4; };"
            "  in (base // overlay).b'"
        ).strip()
        assert out == "99", f"Merge override failed: {out}"

    with subtest("schema: runtime merge order preserved"):
        # shared ← user_shared ← runtime: runtime wins
        out = machine.succeed(
            "nix-instantiate --eval --strict -E '"
            "  let shared      = { version = \"base\"; pkgs = null; };"
            "      user_shared = { version = \"user\"; hostName = \"nixos\"; };"
            "      runtime     = { version = \"runtime\"; isNixOS = true; };"
            "  in (shared // user_shared // runtime).version'"
        ).strip().strip('"')
        assert out == "runtime", f"Runtime merge order wrong: {out}"

    with subtest("schema: secrets attrset is nested"):
        out = machine.succeed(
            "nix-instantiate --eval --strict -E '"
            "  let s = {"
            "    secrets = {"
            "      nixos.core.base.user.password = \"nixos/core/base/user/kilig/password\";"
            "    };"
            "  };"
            "  in s.secrets.nixos.core.base.user.password'"
        ).strip().strip('"')
        assert out == "nixos/core/base/user/kilig/password", \
            f"secrets path mismatch: {out}"
  '';
}
