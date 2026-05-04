# @path: ~/projects/configs/nix-config/home/env/dev/re/default.nix
# @author: redskaber
# @datetime: 2026-05-05
# @description: home::env::dev::re::default
#
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): minimal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language
#
# FIXME: clangd in NixOS header find is idiot, waiting fix Neovim lsp used non-nixos (mason false).

{ pkgs, inputs, shared, dev, ... }:
{
  default = {
    shell = "zsh";

    # 核心工具链
    buildInputs = with pkgs; [
      # clang/llvm 反汇编支持
      llvmPackages.libcxxClang  # clang++ preconfigured wrapper
      libcxx                    # provides libc++ and lib++abi
      clang-tools               # clangd, clang-tidy, clang-format
      lld                       # llvm linker
      lldb                      # llvm debugger
      llvm                      # opt, llc, etc.
                                # build & analysis
      bear                      # compile_commands.json
      ccache                    # compiler cache
                                # common modern c++ libraries (header-only or built against libc++)
      fmt
      spdlog
      eigen

      # --- 反汇编/反编译 (静态分析) ---
      radare2           # 核心框架 (r2, rasm2, rabin2)
      cutter            # Radare2 官方 GUI (Qt)
      binutils          # objdump, readelf, nm, strings
      ghidra            # NSA 开源逆向平台
      bloaty            # 二进制大小分析
      cargo-bloat       # Rust 二进制分析
      binaryninja-free
      # ida-free          # https://my.hex-rays.com/dashboard/download-center/installers/release/9.2/ida-free
                          # nix-store --add-fixed sha256 ida-free-pc_92_x64linux.run
                          # nix-prefetch-url --type sha256 file:///path/to/ida-free-pc_92_x64linux.run

      # --- 调试/动态分析 ---
      gdb               # GNU 调试器 (含 Python 脚本支持)
      strace            # 系统调用追踪
      ltrace            # 库函数调用追踪
      volatility3       # 内存取证框架
      frida-tools       # 动态插桩 (需配合 frida-server)
      qemu_full         # 8.2+ (全系统模拟 + 用户态跨架构)
      scanmem

      python312
      python312Packages.pwntools          # CTF 核心框架
      python312Packages.ropgadget         # ROP 链生成
      python312Packages.pyelftools        # ELF 解析
      python312Packages.capstone          # 反汇编框架
      python312Packages.keystone-engine   # 汇编引擎
      python312Packages.unicorn           # CPU 模拟
      python312Packages.lief              # ELF/PE/Mach-O 操作
      python312Packages.yara-python       # 规则引擎
      # python312Packages.uncompyle6      # Python 字节码反编译 (py3.12 non-sup)
      python312Packages.apkinspector      # Android APK 分析
      python312Packages.scapy             # network packet manipulation program and library


      # --- 固件/嵌入式分析 ---
      binwalk           # 含 entropy 分析
      ubootTools        # mkimage, fw_printenv
      flashrom          # SPI 闪存操作

      # --- Android 专项 ---
      jadx              # Android APK 反编译 (Apache 2.0 但含 unfree 依赖)
      apktool           # APK 重打包工具
      android-tools     # adb, fastboot, aapt

      # --- 恶意软件分析 ---
      yara              # 含官方规则库
      clamav            # 基础扫描
      exiftool          # 元数据提取

      # --- 网络/协议分析 ---
      tshark            # 命令行抓包分析 (TShark)
      tcpdump
      mitmproxy         # 10.3+ (HTTP/2, WebSocket)

      # --- 二进制工具 ---
      imhex             # 现代十六进制编辑器 (GUI,Qt)
      hexyl             # 命令行十六进制查看器
      bvi               # 二进制可视化编辑器
      ddrescue          # 损坏介质数据恢复
      bchunk            # bin/cue 转换
      srecord           # 二进制格式转换

      # --- 沙箱/隔离 (强制) ---
      firejail          # 应用沙箱隔离
      bubblewrap        # 低权限沙箱 (bwrap)
      nsjail

      # --- 辅助工具 ---
      file              # 文件类型识别
      jq                # JSON 处理 (分析元数据)
      yq                # YAML 处理
      exiftool          # 元数据提取
      lrzip             # 高压缩率固件处理
    ];

    nativeBuildInputs = with pkgs; [
      pkg-config
      cmake
      ninja
    ];

    # Shell 环境
    preInputsHook = ''
      echo "[preInputsHook]: Reverse Engining shell!"
    '';

    postInputsHook = ''
      # Use the pure libc++-aware Clang wrapper as default compilers
      export CC="ccache  ${pkgs.llvmPackages.libcxxClang}/bin/clang"
      export CXX="ccache  ${pkgs.llvmPackages.libcxxClang}/bin/clang++"

      # Explicitly set include paths to prefer libc++ headers
      # Note: glibc C headers are still needed (libc is glibc), but C++ must be libc++
      export C_INCLUDE_PATH="${pkgs.glibc.dev}/include"
      export CPLUS_INCLUDE_PATH="${pkgs.libcxx.dev}/include/c++/v1:${pkgs.glibc.dev}/include"

      # Force use of lld linker
      export LD=${pkgs.lld}/bin/ld.lld
      export LDFLAGS="-fuse-ld=lld"

      # Enable color diagnostics
      export CLANG_COLOR_DIAGNOSTICS=always

      # Runtime-Linker
      export LD_LIBRARY_PATH="${pkgs.libcxx}/lib:$LD_LIBRARY_PATH"
      echo "[postInputsHook]: Reverse Engining shell!"
    '';

    preShellHook = ''
      echo "[preShellHook]: Reverse Engining shell!"
    '';

    postShellHook = ''
      echo "[postShellHook]: Reverse Engining shell!"
    '';


  };


}


