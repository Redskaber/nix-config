# @path: ~/projects/configs/nix-config/tests/home/env/dev/python/default.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::env::dev::python::default
# @source: home/env/dev/python/default.nix
#
# Mirrors production buildInputs:
#   python314, uv, ruff, pyright, nodejs_24 (pyright dep)
# nativeBuildInputs: pkg-config
# env: UV_PYTHON, UV_CACHE_DIR, PYTHONPYCACHEPREFIX

{ pkgs, lib, ... }:
{
  name = "home_env_dev_python_default";
  meta = { maintainers = [ "redskaber" ]; timeout = 180; };

  nodes.machine = {
    virtualisation.memorySize = 768;

    environment.systemPackages = with pkgs; [
      python314 # FIXME: python312 doc err
      uv
      ruff
      pyright
      nodejs_24
      pkg-config
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("python_dev: python3.14 present"):
        ver = machine.succeed("python3.14 --version 2>&1").strip()
        print(f"python: {ver}")
        assert "Python 3.14" in ver, f"python3.14 not found: {ver}"

    with subtest("python_dev: basic eval 1+1"):
        out = machine.succeed("python3.14 -c 'print(1+1)'").strip()
        assert out == "2", f"Expected 2, got: {out}"

    with subtest("python_dev: uv present"):
        ver = machine.succeed("uv --version 2>&1").strip()
        print(f"uv: {ver}")
        assert "uv" in ver.lower(), f"uv not found: {ver}"

    with subtest("python_dev: ruff present"):
        ver = machine.succeed("ruff --version 2>&1").strip()
        print(f"ruff: {ver}")
        assert "ruff" in ver.lower()

    with subtest("python_dev: pyright present"):
        w = machine.succeed("which pyright 2>/dev/null || true").strip()
        print(f"pyright: {w}")
        assert "pyright" in w, f"pyright not found: {w}"

    with subtest("python_dev: uv venv creation"):
        machine.succeed("""
          set -e
          cd /tmp
          mkdir -p py_test_venv
          cd py_test_venv
          uv venv .venv 2>&1
          test -f .venv/bin/python
        """)
  '';
}
