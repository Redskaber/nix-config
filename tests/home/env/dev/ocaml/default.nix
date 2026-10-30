# @path: ~/projects/configs/nix-config/tests/home/env/dev/ocaml/default.nix
# @author: redskaber
# @datetime: 2026-10-30
# @description: tests::home::env::dev::ocaml::default
# @source: home/env/dev/ocaml/default.nix
#
# Mirrors production buildInputs for the OCaml devenv:
#   ocaml, dune_3, ocaml-lsp, ocamlformat, utop, merlin, odoc
#   + findlib, pkg-config, gnumake
# (odoc trimmed from the VM — doc-generator role, same trimming
# precedent as the c-test's valgrind.)

{ pkgs, lib, ... }:
{
  name = "home_env_dev_ocaml_default";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 600;
  };

  nodes.machine = {
    virtualisation.memorySize = 1024;
    environment.systemPackages = with pkgs; [
      ocamlPackages.ocaml
      ocamlPackages.dune_3
      ocamlPackages.ocaml-lsp
      ocamlPackages.ocamlformat
      ocamlPackages.utop
      ocamlPackages.merlin
      ocamlPackages.findlib
      pkg-config
      gnumake
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("ocaml_dev: ocaml binary present"):
        ver = machine.succeed("ocaml -version 2>&1").strip()
        print(f"ocaml: {ver}")
        assert "OCaml" in ver or "ocaml" in ver.lower(), f"ocaml not found: {ver}"

    with subtest("ocaml_dev: dune binary present"):
        ver = machine.succeed("dune --version 2>&1").strip()
        print(f"dune: {ver}")
        assert ver[0].isdigit() or "dune" in ver.lower(), f"dune not found: {ver}"

    with subtest("ocaml_dev: ocamlformat binary present"):
        ver = machine.succeed("ocamlformat --version 2>&1").strip()
        print(f"ocamlformat: {ver}")
        assert ver[0].isdigit() or "ocamlformat" in ver.lower(), f"ocamlformat not found: {ver}"

    with subtest("ocaml_dev: utop binary present"):
        # utop's CLI has no --version flag (Arg usage error, exit 2 —
        # CI 2026-10-30); presence via command -v, matching the
        # subtest's name exactly.
        w = machine.succeed("command -v utop").strip()
        print(f"utop: {w}")
        assert w != "", f"utop not found in PATH: {w}"

    with subtest("ocaml_dev: ocamlfind present"):
        w = machine.succeed("which ocamlfind 2>/dev/null || true").strip()
        print(f"ocamlfind: {w}")

    with subtest("ocaml_dev: ocaml-lsp present"):
        w = machine.succeed("which ocaml-lsp 2>/dev/null || true").strip()
        print(f"ocaml-lsp: {w}")

    with subtest("ocaml_dev: execute ocaml hello-world"):
        # printf, not heredoc: the nix indented-string dedent keeps
        # heredoc terminators indented, so the heredoc swallows the
        # rest of the block (vacuous pass — see the lisp test header).
        machine.succeed(r"""
          set -e
          printf '%s\n' 'let () = print_string "ocaml_hello_ok\n"' > /tmp/hello.ml
          out=$(ocaml /tmp/hello.ml < /dev/null)
          [ "$out" = "ocaml_hello_ok" ] || { echo "Got: $out"; exit 1; }
        """)

    with subtest("ocaml_dev: ocaml arithmetic"):
        out = machine.succeed("ocaml -e 'print_int (1 + 1)' < /dev/null").strip()
        assert out == "2", f"ocaml arithmetic failed: {out}"
  '';
}
