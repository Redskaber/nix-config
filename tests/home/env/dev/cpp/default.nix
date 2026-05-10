# @path: ~/projects/configs/nix-config/tests/home/env/dev/cpp/default.nix
# @author: redskaber
# @datetime: 2026-05-10
# @description: tests::home::env::dev::cpp::default
# @source: home/env/dev/cpp/default.nix

{ pkgs, lib, ... }:
{
  name = "home_env_dev_cpp_default";
  meta = { maintainers = [ "redskaber" ]; timeout = 300; };

  nodes.machine = {
    virtualisation.memorySize = 768;
    environment.systemPackages = with pkgs; [
      gcc
      clang-tools
      cmake
      gnumake
      ninja
    ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("cpp_dev: g++ binary present"):
        ver = machine.succeed("g++ --version 2>&1 | head -1").strip()
        print(f"g++: {ver}")
        assert "g++" in ver.lower() or "gcc" in ver.lower(), f"g++ not found: {ver}"

    with subtest("cpp_dev: clangd present"):
        w = machine.succeed("which clangd").strip()
        assert "clangd" in w, f"clangd not found: {w}"

    with subtest("cpp_dev: cmake present"):
        ver = machine.succeed("cmake --version 2>&1 | head -1").strip()
        assert "cmake" in ver.lower(), f"cmake not found: {ver}"

    with subtest("cpp_dev: ninja present"):
        ver = machine.succeed("ninja --version 2>&1").strip()
        print(f"ninja: {ver}")
        assert ver != "", "ninja not found"

    with subtest("cpp_dev: compile and run hello-world"):
        machine.succeed(r"""
          set -e
          cat > /tmp/hello.cpp << 'CPPEOF'
          #include <iostream>
          int main() { std::cout << "cpp_hello_ok" << std::endl; return 0; }
          CPPEOF
          g++ -o /tmp/hello_cpp /tmp/hello.cpp
          out=$(/tmp/hello_cpp)
          [ "$out" = "cpp_hello_ok" ] || { echo "Got: $out"; exit 1; }
        """)
  '';
}
