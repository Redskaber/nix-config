# @path: ~/projects/configs/nix-config/tests/home/env/dev/lisp/default.nix
# @author: redskaber
# @datetime: 2026-10-30
# @description: tests::home::env::dev::lisp::default
# @source: home/env/dev/lisp/default.nix
#
# Mirrors production buildInputs for the Common Lisp devenv:
#   sbcl, rlwrap, clinfo, pkg-config, gcc, gnumake
#
# Heredoc discipline (CI 2026-10-30 incident): the nix '' dedent
# strips only the common prefix, so the r""" payload keeps its
# inner indentation — a `<< 'EOF'` terminator never lands in
# column 0, the heredoc runs to end-of-input and swallows every
# command after it (the cat-form subtest passed VACUOUSLY; the
# `sbcl --script /dev/stdin` form fed the stray terminator line to
# the reader and failed for real). Fixture files are written with
# printf '%s\n' single-quoted args — indentation-immune by
# construction.

{ pkgs, lib, ... }:
{
  name = "home_env_dev_lisp_default";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 300;
  };

  nodes.machine = {
    virtualisation.memorySize = 768;
    environment.systemPackages = with pkgs; [
      sbcl
      rlwrap
      clinfo
      gcc
      gnumake
      pkg-config
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("lisp_dev: sbcl binary present"):
        ver = machine.succeed("sbcl --version 2>&1").strip()
        print(f"sbcl: {ver}")
        assert "SBCL" in ver, f"sbcl not found: {ver}"

    with subtest("lisp_dev: rlwrap binary present"):
        ver = machine.succeed("rlwrap --version 2>&1 | head -1").strip()
        print(f"rlwrap: {ver}")
        assert "rlwrap" in ver.lower(), f"rlwrap not found: {ver}"

    with subtest("lisp_dev: clinfo binary present"):
        w = machine.succeed("command -v clinfo").strip()
        print(f"clinfo: {w}")
        assert w != "", f"clinfo not found in PATH: {w}"

    with subtest("lisp_dev: gcc fallback toolchain present"):
        ver = machine.succeed("gcc --version 2>&1 | head -1").strip()
        print(f"gcc: {ver}")
        assert "gcc" in ver.lower(), f"gcc not found: {ver}"

    with subtest("lisp_dev: execute sbcl script"):
        machine.succeed(r"""
          set -e
          printf '%s\n' '(write-line "lisp_hello_ok")' > /tmp/hello.lisp
          out=$(sbcl --script /tmp/hello.lisp)
          [ "$out" = "lisp_hello_ok" ] || { echo "Got: $out"; exit 1; }
        """)

    with subtest("lisp_dev: sbcl arithmetic"):
        out = machine.succeed(r"""
          printf '%s\n' '(format t "~a" (+ 1 1))' > /tmp/arith.lisp
          sbcl --script /tmp/arith.lisp
        """).strip()
        assert out == "2", f"sbcl arithmetic failed: {out}"
  '';
}
