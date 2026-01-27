# @path: ~/projects/configs/nix-config/home/core/dev/nix.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::dev::nix
#
# Modern Nix development environment — aligned with RFC 109 and community best practices
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, dev, ... }: {
  # base attrset
  default = {

    buildInputs = with pkgs; [
      nix                        # Core runtime (with flakes, experimental features)
      nixfmt-rfc-style           # Formatter(RFC 109): Officially endorsed formatter
      statix                     # Linter(static analysis): Detects anti-patterns, unused bindings, etc.
      deadnix                    # Dead-code-eliminayion: Removes unused definitions
      nil                        # Language-Server-Protocol: Fast, official LSP by NixOS team (supports flakes, overlays, etc.)

      # Optional but useful:
      # nix-output-monitor       # Visualize build outputs (great for CI/debugging)
      # nix-tree                 # Explore closure dependencies interactively
    ];

    nativeBuildInputs = with pkgs; [
      # Usually empty for pure Nix dev
    ];

    preInputsHook = ''
      echo "[preInputsHook]: nix shell!"
    '';
    postInputsHook = ''
      echo "[postInputsHook]: nix shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: nix shell!"
    '';
    postShellHook = ''
      echo "[postShellHook]: nix shell!"
    '';

  };

  # nix-derivation custom shell attrset
  derivation = {
    buildInputs = with pkgs; [
      # === 核心构建与打包 ===
      autoPatchelfHook
      makeWrapper
      wrapGAppsHook
      dpkg
      rpmextract
      appimage-run
      binutils
      file
      glibc
      patchelf                     # 必须显式提供（autoPatchelfHook 依赖它）

      # === FHS / 沙盒支持（Steam/闭源商业软件）===
      buildFHSEnv                  # 创建 FHS 兼容环境
      bubblewrap                   # Steam 和现代沙盒依赖

      # === 依赖分析与调试 ===
      nix-index
      nix-locate
      nvd
      nix-tree
      nix-output-monitor
      readelf                      # 来自 binutils，但显式强调
      ldd                          # alias to  $ {glibc}/bin/ldd

      # === GUI / 图形栈（QQ, WeChat, Hyprland, Steam, etc）===
      glib
      gtk3
      qt5.qtbase                  # 部分闭源软件用 Qt
      alsa-lib
      pipewire                    # 现代音频（替代 PulseAudio）
      libpulseaudio               # 兼容旧版
      dbus
      systemd
      mesa
      vulkan-loader               # Steam/Vulkan 游戏
      libglvnd                    # OpenGL 多供应商支持
      wayland
      wlroots
      libx11
      libxcb
      xcb-util
      xcb-util-errors
      xcb-util-renderutil
      xdg-utils
      desktop-file-utils          # 验证 .desktop 文件
      libnotify
      libappindicator-gtk3
      cups
      libsecret                   # 密码存储（WeChat/QQ）
      libv4l                      # 摄像头支持
      ffmpeg                      # 屏幕录制（Hyprland）、视频解码

      # === 字体与本地化 ===
      fontconfig
      freetype
      dejavu_fonts
      noto-fonts
      noto-fonts-cjk              # 中文支持（QQ/WeChat 必需）
      gnome-themes-extra
      adwaita-icon-theme

      # === 游戏/多媒体扩展 ===
      sdl2
      openal
      libusb
      hwdata
    ];

    nativeBuildInputs = with pkgs; [
      patchelf
      desktop-file-utils
      makeWrapper
      autoPatchelfHook
    ];

    preShellHook = ''
      echo "[derivation] Entering comprehensive Nix derivation dev environment"
      echo "→ For .deb: 'dpkg-deb -x pkg.deb .' or 'ar x pkg.deb && tar -xf data.tar.*'"
      echo "→ For dependencies: run 'nix-index' once, then 'nix-locate libfoo.so'"
      echo "→ For FHS apps (e.g., Steam): use 'buildFHSEnv' in your derivation"
      echo "→ For GPU: ensure mesa/vulkan are in buildInputs"
    '';

    postShellHook = ''
      if ! [ -f " $ HOME/.nix-index/files" ]; then
        echo "⚠️  Run 'nix-index' to enable fast 'nix-locate' queries."
      fi
    '';
  }


}



