# @path: ~/projects/configs/nix-config/nixos/core/exp/obs.nix
# @author: redskaber
# @datetime: 2026-03-01
# @description: nixos::core::exp::obs
# - obs in nixos core, if you need vitural camera, else can home-manager impl.

{
  inputs,
  shared,
  lib,
  config,
  pkgs,
  ...
}:
{

  programs.obs-studio = {
    enable = true;
    package = pkgs.obs-studio;
    enableVirtualCamera = true;
    plugins = with pkgs.obs-studio-plugins; [
      # === Wayland 核心支持 (必选) ===
      wlrobs                            # Wayland 屏幕捕获 (wlroots compositor)
      obs-pipewire-audio-capture        # PipeWire 音频/应用捕获 (Wayland 音频基石)

      # === 画面增强与虚拟制作 ===
      obs-backgroundremoval             # AI 虚拟背景 (MIT 许可，轻量高效)
      obs-composite-blur                # 多算法模糊 (背景虚化/隐私保护)
      obs-shaderfilter                  # 自定义着色器滤镜 (高级视觉效果)

      # === 自动化与工作流 ===
      advanced-scene-switcher           # 条件触发场景切换 (窗口标题/音频/定时等)
      obs-websocket                     # 远程控制 (StreamDeck/OBS Controller 兼容，legacy 4.9.1 协议)
      obs-command-source                # 场景切换时执行系统命令 (自动化脚本集成)

      # === 多平台与网络 ===
      obs-teleport                      # NDI 替代方案 (原 obs-ndi，跨设备音视频传输)
      obs-aitum-multistream             # 单实例多平台推流 (Twitch/YouTube/B站等)

      # === 直播增强组件 ===
      input-overlay                     # 键鼠/手柄输入可视化 (游戏直播必备)
      obs-tuna                          # 音乐元数据显示 (Spotify/MPD 等)
      obs-media-controls                # 媒体播放控制面板 (暂停/音量快捷操作)
      obs-markdown                      # Markdown 文本源 (简洁字幕/说明)

      # === 捕获扩展 (按需启用) ===
      # obs-vkcapture                   # Vulkan/OpenGL 游戏捕获 (若 wlrobs 捕获游戏失效时备用)
      # droidcam-obs"                   # 手机摄像头接入 (需配合 DroidCam App)
      # obs-livesplit-one"              # 速通计时器集成 (游戏竞速场景)
    ];
  };

}
