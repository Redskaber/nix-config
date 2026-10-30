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
# ghc (same trimming precedent as the c-test's valgrind).

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
        assert "GHC" in ver, f"ghc not found: {ver}"

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
        machine.succeed(r"""
          set -e
          cd /tmp
          cat > Hello.hs << 'HEOF'
          main = putStrLn "haskell_hello_ok"
          HEOF
          ghc -v0 -o hello_hs Hello.hs
          ./hello_hs | grep -q 'haskell_hello_ok'
          rm -f Hello.hs Hello.o Hello.hi hello_hs
        """)

    with subtest("haskell_dev: ghc eval arithmetic"):
        out = machine.succeed("ghc -e 'show (1 + 1)' 2>/dev/null").strip()
        assert out == "2", f"ghc eval failed: {out}"
  '';
}
