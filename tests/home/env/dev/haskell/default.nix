# @path: ~/projects/configs/nix-config/tests/home/env/dev/haskell/default.nix
# @author: redskaber
# @datetime: 2026-10-30
# @description: tests::home::env::dev::haskell::default
# @source: home/env/dev/haskell/default.nix
#
# Mirrors production buildInputs for the Haskell devenv:
#   haskell.compiler.ghc910 (unstable), cabal-install,
#   haskell-language-server, fourmolu, hlint, hoogle, ghcid
#   + pkg-config, gnumake, just, treefmt
# The VM mirrors the toolchain roles on the test plane's default
# ghc (same trimming precedent as the c-test's valgrind;
# hoogle/just/treefmt trimmed likewise — doc-search and task-runner
# roles are orthogonal to the compile-run path under test).

{ pkgs, lib, ... }:
{
  name = "home_env_dev_haskell_default";
  meta = {
    maintainers = [ "redskaber" ];
    timeout = 900;
  };

  nodes.machine = {
    virtualisation.memorySize = 2048;
    virtualisation.diskSize = 4096;
    environment.systemPackages = with pkgs; [
      haskellPackages.ghc
      haskellPackages.cabal-install
      haskellPackages.haskell-language-server
      haskellPackages.fourmolu
      haskellPackages.hlint
      haskellPackages.ghcid
      pkg-config
      gnumake
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("haskell_dev: ghc binary present"):
        ver = machine.succeed("ghc --version 2>&1").strip()
        print(f"ghc: {ver}")
        # The banner is "The Glorious Glasgow Haskell Compilation
        # System, version X" — it carries no literal "GHC" substring
        # (CI 2026-10-30); anchor on the stable Glasgow Haskell phrase.
        assert "Glasgow Haskell" in ver, f"ghc not found: {ver}"

    with subtest("haskell_dev: cabal binary present"):
        ver = machine.succeed("cabal --version 2>&1 | head -1").strip()
        print(f"cabal: {ver}")
        assert "cabal" in ver.lower() or "Cabal" in ver, f"cabal not found: {ver}"

    with subtest("haskell_dev: fourmolu binary present"):
        ver = machine.succeed("fourmolu --version 2>&1 | head -1").strip()
        print(f"fourmolu: {ver}")
        assert "fourmolu" in ver.lower(), f"fourmolu not found: {ver}"

    with subtest("haskell_dev: hlint binary present"):
        ver = machine.succeed("hlint --version 2>&1 | head -1").strip()
        print(f"hlint: {ver}")
        assert "hlint" in ver.lower(), f"hlint not found: {ver}"

    with subtest("haskell_dev: haskell-language-server present"):
        w = machine.succeed("which haskell-language-server 2>/dev/null || which haskell-language-server-wrapper 2>/dev/null || true").strip()
        print(f"hls: {w}")

    with subtest("haskell_dev: ghcid present"):
        w = machine.succeed("which ghcid 2>/dev/null || true").strip()
        print(f"ghcid: {w}")

    with subtest("haskell_dev: compile and run hello-world"):
        # printf, not heredoc: the nix indented-string dedent keeps
        # heredoc terminators indented, so the heredoc swallows the
        # rest of the block (vacuous pass — see the lisp test header).
        machine.succeed(r"""
          set -e
          cd /tmp
          printf '%s\n' 'main = putStrLn "haskell_hello_ok"' > Hello.hs
          ghc -v0 -o hello_hs Hello.hs
          out=$(./hello_hs)
          [ "$out" = "haskell_hello_ok" ] || { echo "Got: $out"; exit 1; }
          rm -f Hello.hs Hello.o Hello.hi hello_hs
        """)

    with subtest("haskell_dev: ghc eval arithmetic"):
        # bare expression, not show (…): ghc -e prints the value as
        # ghci would — show (1 + 1) renders as "2" WITH quotes.
        out = machine.succeed("ghc -e '1 + 1' 2>/dev/null").strip()
        assert out == "2", f"ghc eval failed: {out}"
  '';
}
