# @path: ~/projects/configs/nix-config/home/core/app/rev-eng/ghidra.nix
# @author: redskaber
# @datetime: 2026-03-07
# @description: home::core::app::rev-eng::ghidra


{ inputs
, shared
, lib
, config
, pkgs
, ...
}:
{

  home.packages = with pkgs; [
    # 反编译/反汇编
    ghidra
    # ghidra-extensions.wasm
    # Radare2
    # cutter
    # binaryninja-free

    # 调试器
    # gdb
    # lldb
    # frida-tools

    # 十六进制/二进制
    # imhex
    # bless

    # 辅助工具
    # pwntools
    # ropgadget
    # binutils
    # strace
    # ltrace

    # 网络/沙箱
    # wireshark
    # qemu
    # firejail

  ];

}

