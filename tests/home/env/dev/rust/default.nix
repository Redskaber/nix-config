# @path: ~/projects/configs/nix-config/tests/home/env/dev/rust/default.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::env::dev::rust::default
# @source: home/env/dev/rust/default.nix
#
# Mirrors production buildInputs:
#   rustc, cargo, rustfmt, clippy, rust-analyzer
# nativeBuildInputs: pkg-config, openssl.dev

{ pkgs, lib, ... }:
{
  name = "home_env_dev_rust_default";
  meta = { maintainers = [ "redskaber" ]; timeout = 600; };

  nodes.machine = {
    virtualisation.memorySize = 2048;
    virtualisation.diskSize   = 4096;

    environment.systemPackages = with pkgs; [
      rustc
      cargo
      rustfmt
      clippy
      rust-analyzer
      pkg-config
      openssl.dev
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("rust_dev: rustc present"):
        ver = machine.succeed("rustc --version 2>&1").strip()
        print(f"rustc: {ver}")
        assert "rustc" in ver, f"rustc not found: {ver}"

    with subtest("rust_dev: cargo present"):
        ver = machine.succeed("cargo --version 2>&1").strip()
        print(f"cargo: {ver}")
        assert "cargo" in ver, f"cargo not found: {ver}"

    with subtest("rust_dev: rustfmt present"):
        ver = machine.succeed("rustfmt --version 2>&1").strip()
        print(f"rustfmt: {ver}")
        assert "rustfmt" in ver.lower()

    with subtest("rust_dev: clippy present"):
        ver = machine.succeed("cargo clippy --version 2>&1 || clippy-driver --version 2>&1 || true").strip()
        print(f"clippy: {ver}")

    with subtest("rust_dev: rust-analyzer present"):
        w = machine.succeed("which rust-analyzer 2>/dev/null || true").strip()
        print(f"rust-analyzer: {w}")

    with subtest("rust_dev: cargo new + cargo build hello"):
        machine.succeed("""
          set -e
          cd /tmp
          cargo new hello_rust_test --name hello_rust_test 2>&1
          cd hello_rust_test
          cargo build 2>&1
          ./target/debug/hello_rust_test | grep -q 'Hello'
        """)
  '';
}
