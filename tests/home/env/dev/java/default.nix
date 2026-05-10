# @path: ~/projects/configs/nix-config/tests/home/env/dev/java/default.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: tests::home::env::dev::java::default
# @source: home/env/dev/java/default.nix

{ pkgs, lib, ... }:
{
  name = "home_env_dev_java_default";
  meta = { maintainers = [ "redskaber" ]; timeout = 300; };

  nodes.machine = {
    virtualisation.memorySize = 1024;
    environment.systemPackages = with pkgs; [
      jdk21
      maven
      gradle
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("java_dev: java binary present"):
        ver = machine.succeed("java --version 2>&1 | head -1").strip()
        print(f"java: {ver}")
        assert "java" in ver.lower() or "openjdk" in ver.lower(), f"java not found: {ver}"

    with subtest("java_dev: javac binary present"):
        ver = machine.succeed("javac --version 2>&1").strip()
        print(f"javac: {ver}")
        assert "javac" in ver, f"javac not found: {ver}"

    with subtest("java_dev: maven present"):
        ver = machine.succeed("mvn --version 2>&1 | head -1").strip()
        print(f"mvn: {ver}")
        assert "Apache Maven" in ver or "mvn" in ver.lower(), f"maven not found: {ver}"

    with subtest("java_dev: compile and run hello-world"):
        machine.succeed(r"""
          set -e
          mkdir -p /tmp/java_hello
          cat > /tmp/java_hello/Hello.java << 'JEOF'
          public class Hello {
              public static void main(String[] args) {
                  System.out.println("java_hello_ok");
              }
          }
          JEOF
          cd /tmp/java_hello
          javac Hello.java
          out=$(java Hello)
          [ "$out" = "java_hello_ok" ] || { echo "Got: $out"; exit 1; }
        """)
  '';
}
