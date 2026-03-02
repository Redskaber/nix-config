# @path: ~/projects/configs/nix-config/home/core/app/music/easyeffects.nix
# @author: redskaber
# @datetime: 2026-02-14
# @description: home::core::app::music::easyeffects

{ inputs
, lib
, config
, pkgs
, ...
}:
{
  # ===== 实用工具包 =====
  home.packages = with pkgs; [
    easyeffects      # easyeffects gui 配置界面
  ];

  # ===== EasyEffects 配置 =====
  services.easyeffects = {
    enable = true;
    preset = "music";           # 激活预设

    # 专业级音频处理配置
    extraPresets = {
      music = {
        output = {
          # 处理器顺序
          "plugins_order" = [
            "equalizer#0"       # 30段均衡器
            "bass_enhancer#0"   # 低音增强
          ];

          # 30段均衡器
          "equalizer#0" = {
            bypass = false;
            "input-gain" = 0.0;
            "output-gain" = 0.0;
            preset = "custom";
            "num-bands" = 30;
            bands = [
              # 低频增强 (31Hz-125Hz)
              { frequency = 31.25; gain = 1.0; quality = 1.0; type = "Bell"; }
              { frequency = 62.5; gain = 1.5; quality = 1.0; type = "Bell"; }
              { frequency = 125; gain = 1.0; quality = 1.0; type = "Bell"; }
              # 中频优化 (250Hz-2kHz)
              { frequency = 250; gain = 0.5; quality = 1.0; type = "Bell"; }
              { frequency = 500; gain = 0.0; quality = 1.0; type = "Bell"; }
              { frequency = 1000; gain = -0.5; quality = 1.0; type = "Bell"; }
              { frequency = 2000; gain = -1.0; quality = 1.0; type = "Bell"; }
              # 高频提亮 (4kHz-16kHz)
              { frequency = 4000; gain = 0.5; quality = 1.0; type = "Bell"; }
              { frequency = 8000; gain = 1.5; quality = 1.0; type = "Bell"; }
              { frequency = 16000; gain = 2.0; quality = 1.0; type = "Bell"; }
            ];
          };

          # 低音增强器 (物理)
          "bass_enhancer#0" = {
            bypass = false;
            amount = 3.5;      # 增强强度
            "harmonics" = 8.5; # 谐波生成
            "scope" = 100.0;   # 作用频率范围
            "floor" = 20.0;    # 最低生效频率(Hz)
            "blend" = 0.0;     # 原始/增强混合比
          };
        };
      };
    };
  };


}


