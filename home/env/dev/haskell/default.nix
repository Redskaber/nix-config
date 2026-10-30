# @path: ~/projects/configs/nix-config/home/env/dev/haskell/default.nix
# @author: redskaber
# @datetime: 2026-10-29
# @description: home::env::dev::haskell::default
#
# Haskell development environment — GHC + HLS + 工具链
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): 推荐基线 Haskell 工具链
# - <variant> : (custom     , custom, optional  ): 特定 GHC 版本或特性集

{
  pkgs,
  inputs,
  shared,
  dev,
  ...
}:
{
  default = {
    shell = shared.user.shell.tag;
    buildInputs = with shared.upkgs; [
      haskell.compiler.ghc910 # 编译器
      haskellPackages.cabal-install # 构建与包管理
      haskellPackages.haskell-language-server # 语言服务器（补全、跳转、类型信息等）
      haskellPackages.fourmolu # 格式化（Ormolu 的可配置分支，HLS 可直接集成）[reference:4]
      haskellPackages.hlint # 静态检查与风格建议
      haskellPackages.hoogle # 本地 API 文档搜索
      haskellPackages.ghcid # 轻量级重载/快速反馈
    ];

    nativeBuildInputs = with shared.pkgs; [
      pkg-config
      gnumake # 可选：Makefile 项目
      just # 可选：任务运行器（srid/haskell-template 默认使用 just）
      treefmt # 可选：多语言统一格式化入口
    ];

    preInputsHook = ''
      echo "[preInputsHook]: haskell environment loading..."
    '';

    postInputsHook = ''
      echo "[postInputsHook]: haskell environment ready."
      echo "  GHC     : $(ghc --version)"
      echo "  Cabal   : $(cabal --version | head -n1)"
      echo "  HLS     : $(haskell-language-server-wrapper --version 2>/dev/null || echo 'wrapper available')"
    '';

    preShellHook = ''
      echo "[preShellHook]: entering haskell shell..."
    '';

    postShellHook = ''
      echo "[postShellHook]: haskell shell active."
      echo "  Tip: hls 已按 GHC 版本绑定；若切换 GHC 请同步修改 supportedGhcVersions。"
      echo "  Tip: fourmolu -i <file> 就地格式化；hlint <file> 做静态检查。"
    '';
  };
}
