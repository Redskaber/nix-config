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
  # === 开源项目构建环境 ===
  # 专注：Nix 表达式开发、PR 审查、社区协作、可复现构建
  free-derivation = {

    buildInputs = with pkgs; [
      nix                          # 核心工具链（含 flakes 支持）
      nixfmt-rfc-style             # RFC 109 官方格式化器
      statix                       # 静态分析（检测反模式/未使用绑定）
      deadnix                      # 死代码清理
      nil                          # 官方 LSP（支持 flakes/overlays）

      # 构建诊断与可视化
      nix-output-monitor           # 实时构建输出可视化（CI/调试利器）
      nix-tree                     # 交互式依赖树探索
      nix-diff                     # derivation 差异对比
      nvd                          # Nix 漏洞数据库扫描（安全审计）

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

  # === 闭源/专有软件构建环境 ===
  # 专注：二进制封装、许可证合规、非自由依赖处理、安全交付
  unfree-derivation = {
    buildInputs = with pkgs; [
      nix
      patchelf                     # ELF 二进制重定向（关键！修复 RPATH/interpreter）
      chrpath                      # 修改二进制 RPATH（轻量替代 patchelf）
      makeself                     # 创建自解压安装包（.run 格式）
      appimage-run                 # 运行 AppImage 时支持
      fpm                          # 多格式包转换（deb/rpm等）
      licensecheck                 # 依赖许可证扫描（合规审计）
      jq                           # 许可证元数据处理
      gnupg                        # 签名/验证（交付物完整性）
      sbomnix                      # 生成 SPDX SBOM（软件物料清单）
    ];

    preInputsHook = ''
      echo "[preInputsHook]: nix unfree-derivation shell!"
    '';
    postInputsHook = ''
      echo "[postInputsHook]: nix unfree-derivation shell!"
    '';
    preShellHook = ''
      echo "[preShellHook]: nix unfree-derivation shell!"
    '';
    postShellHook = ''
      echo "🔒 [Nix Derivation Shell] Proprietary Software Environment"
      echo "   WARNING: Building non-free software requires 'allowUnfree = true' in your nixpkgs config"
      echo "   Tools: patchelf | makeself | licensefinder | sbomnix | GPG signing"
      echo "   Focus: Binary wrapping • License compliance • Secure delivery"

      # Unfree tips
      cat <<'EOF'
      ⚠️  CRITICAL REMINDERS:
      . Set in your flake.nix:
        nixpkgs.config.allowUnfree = true;
      . NEVER commit proprietary binaries to VCS
      . Validate licenses with: licensefinder
      . Generate SBOM: sbomnix . --output sbom.spdx
      EOF

      # Custom workflow alias
      alias wrap-bin='patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)"'
      alias make-delivery='makeself . installer.run "Unfree Installer"'
      alias check-licenses='licensecheck -r .'
      alias sign-artifact='gpg --detach-sign'

      # auto-set safeenv var
      export PROPRIETARY_BUILD=1
      export NIXPKGS_ALLOW_UNFREE_PROMPT=0  # 避免交互阻塞（need allowUnfree）
      echo "[postShellHook]: nix unfree-derivation shell!"
    '';
    # Import：闭源构建需显式启用非自由包（由用户在 flake.nix 中配置）
    # 此处仅提供工具链，不包含非自由 runtime（如 MATLAB/JetBrains 等）
    # 用户应在 flake 输入中声明：inputs.nixpkgs.config.allowUnfree = true;
  };


}



