# @path: ~/projects/configs/nix-config/tests/home/env/dev/go/default.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::env::dev::go::default
# @source: home/env/dev/go/default.nix
#
# Mirrors production buildInputs:
#   go, gopls, delve, go-tools, golangci-lint, gofumpt,
#   gotests, gomodifytags, impl, richgo

{ pkgs, lib, ... }:
{
  name = "home_env_dev_go_default";
  meta = { maintainers = [ "redskaber" ]; timeout = 300; };

  nodes.machine = {
    virtualisation.memorySize = 1024;

    environment.systemPackages = with pkgs; [
      go
      gopls
      delve
      gotools
      golangci-lint
      gofumpt
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("go_dev: go binary present"):
        ver = machine.succeed("go version 2>&1").strip()
        print(f"go: {ver}")
        assert "go" in ver, f"go not found: {ver}"

    with subtest("go_dev: gopls present"):
        w = machine.succeed("which gopls").strip()
        assert "gopls" in w, f"gopls not found: {w}"

    with subtest("go_dev: delve (dlv) present"):
        w = machine.succeed("which dlv 2>/dev/null || true").strip()
        print(f"dlv: {w}")

    with subtest("go_dev: golangci-lint present"):
        w = machine.succeed("which golangci-lint").strip()
        assert "golangci-lint" in w

    with subtest("go_dev: gofumpt present"):
        w = machine.succeed("which gofumpt").strip()
        assert "gofumpt" in w

    with subtest("go_dev: go run hello-world"):
        machine.succeed("""
          set -e
          mkdir -p /tmp/go_hello
          cat > /tmp/go_hello/main.go << 'GOEOF'
package main
import "fmt"
func main() { fmt.Println("go_hello_ok") }
GOEOF
          cd /tmp/go_hello
          go run main.go 2>&1 | grep -q 'go_hello_ok'
        """)
  '';
}
