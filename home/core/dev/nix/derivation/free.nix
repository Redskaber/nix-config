# @path: ~/projects/configs/nix-config/home/core/dev/nix/derivation/free.nix.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::dev::nix::derivation::free
#
# Modern Nix development environment — aligned with RFC 109 and community best practices
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, ... }: {

  # nix-derivation custom shell attrset
  # === 开源项目构建环境 ===
  # 专注：Nix 表达式开发、PR 审查、社区协作、可复现构建
  default = {

    buildInputs = with pkgs; [
      nix                          # 核心工具链（含 flakes 支持）
      nixfmt-rfc-style             # RFC 109 官方格式化器
      statix                       # 静态分析（检测反模式/未使用绑定）
      alejandra                    # Format specifications
      deadnix                      # 死代码清理
      nil                          # 官方 LSP（支持 flakes/overlays）

      # vulnix                     # NixOS vulnerability scanner (need python env)

      # 构建诊断与可视化
      nix-output-monitor           # 实时构建输出可视化（CI/调试利器）
      nix-tree                     # 交互式依赖树探索
      nix-diff                     # derivation 差异对比
      nvd                          # Nix/NixOS package version diff tool

      # 社区协作工具
      nixpkgs-review               # PR 审查工作流（自动构建/测试）
      nix-index                    # 快速包搜索（`nix-locate`）
      nix-search                   # 增强版包搜索（支持正则）
    ];

    preInputsHook = ''
      echo "[preInputsHook]: nix free-derivation shell!"
    '';
    postInputsHook = ''
      echo "[postInputsHook]: nix free-derivation shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: nix free-derivation shell!"
    '';
    postShellHook = ''
      echo "⬢ [Nix Derivation Shell] Open Source Environment"
      echo "   Tools: nixpkgs-review | nix-tree | nvd | nix-output-monitor"
      echo "   Workflow: nixpkgs PR review • reproducible builds • community standards"

      # Alias
      alias nb='nix build --print-build-logs'
      alias nreview='nixpkgs-review rev HEAD'
      alias ndiff='nix-diff'
      alias ntree='nix-tree'

      # auto-active nix-output-monitor（若终端支持）
      if [ -t 1 ]; then
        export NIX_BUILD_HOOK="nix-output-monitor"
      fi
      echo "[postShellHook]: nix free-derivation shell!"
    '';
  };

}


