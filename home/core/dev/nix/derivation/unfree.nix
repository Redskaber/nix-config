# @path: ~/projects/configs/nix-config/home/core/dev/nix/derivation/unfree.nix
# @author: redskaber
# @datetime: 2025-12-12
# @description: home::core::dev::nix::derivation::unfree
#
# Modern Nix development environment — aligned with RFC 109 and community best practices
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): niminal version and global base runtime environment.
# - <variant> : (custom     , custom, optional  ): specific feature or version configuration items for the language


{ pkgs, inputs, ... }: {

  # === 闭源/专有软件构建环境 ===
  # 专注：二进制封装、许可证合规、非自由依赖处理、安全交付
  default = {
    buildInputs = with pkgs; [
      nix
      patchelf                     # ELF 二进制重定向（关键！修复 RPATH/interpreter）
      chrpath                      # 修改二进制 RPATH（轻量替代 patchelf）
      makeself                     # 创建自解压安装包（.run 格式）
      appimage-run                 # 运行 AppImage 时支持
      fpm                          # 多格式包转换（deb/rpm等）
      hawkeye                      # 依赖许可证扫描（合规审计）
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


