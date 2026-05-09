# @path: ~/projects/configs/nix-config/tests/test_calc.nix
# @author: redskaber
# @datetime: 2026-05-08
# @description: tests::smoke — baseline sanity check
# (original file preserved unchanged)

{ pkgs, lib, ... }:
{
  name = "test_calc";
  meta = {
    maintainers = [ "redskaber" ];
  };

  nodes.machine = {}; # test obj
  testScript = ''
    start_all()

    # wait graph loading
    machine.wait_for_unit("multi-user.target")
    machine.screenshot("postboot")                    # 图形屏幕 tty1~7

    with subtest("TEST::helloworld"):
        msg = machine.succeed("echo 'hello, world!'") # 串口控制台 ttyS0
        print(f"echo output: {msg.strip()}")
        assert msg.strip() == "hello, world!", f"Unexpected: {msg}"

    with subtest("TEST::calculate"):
        result = machine.succeed("echo $((1 + 1))")
        print(f"calc result: {result.strip()}")
        assert result.strip() == "2", f"Expected 2, got: {result.strip()}"

  '';
}
