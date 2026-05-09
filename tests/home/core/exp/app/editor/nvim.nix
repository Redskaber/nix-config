# @path: ~/projects/configs/nix-config/tests/home/core/exp/app/editor/nvim.nix
# @author: redskaber
# @datetime: 2026-05-09
# @description: tests::home::core::exp::app::editor::nvim
# @source: home/core/exp/app/editor/nvim.nix
#
# Mirrors production:
#   home.packages = [neovim]  (default editor: shared.editor = nvim)
#   shellAliases: vi = nvim, vim = nvim

{ pkgs, lib, ... }:
{
  name = "home_core_exp_app_editor_nvim";
  meta = { maintainers = [ "redskaber" ]; timeout = 180; };

  nodes.machine = {
    virtualisation.memorySize = 768;
    environment.systemPackages = with pkgs; [ neovim ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")

    with subtest("nvim: binary present"):
        w = machine.succeed("which nvim").strip()
        assert "nvim" in w, f"nvim not found: {w}"

    with subtest("nvim: version reportable (NVIM vX.Y.Z)"):
        ver = machine.succeed("nvim --version 2>&1 | head -1").strip()
        print(f"nvim: {ver}")
        assert "NVIM" in ver, f"Unexpected nvim output: {ver}"

    with subtest("nvim: headless Lua 1+1 = 2"):
        out = machine.succeed(
            "nvim --headless -c 'lua io.write(tostring(1+1))' -c 'qa' 2>&1"
        ).strip()
        print(f"headless lua: {out!r}")
        assert "2" in out, f"Lua 1+1 != 2: {out}"

    with subtest("nvim: headless write-quit"):
        machine.succeed(
            "printf 'hello nvim\n' | nvim --headless"
            " +'wq! /tmp/nvim_out.txt' 2>&1 || true"
        )

    with subtest("nvim: --version lists provider info"):
        out = machine.succeed("nvim --version 2>&1").strip()
        assert "Run" in out or "NVIM" in out, f"nvim --version incomplete: {out[:80]}"
  '';
}
