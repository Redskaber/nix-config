# @path: ~/projects/configs/nix-config/home/env/dev/ocaml/default.nix
# @author: redskaber
# @datetime: 2026-10-29
# @description: home::env::dev::ocaml::default
#
# OCaml development environment — OCaml 5 + Dune + ocaml-lsp + 工具链
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): 推荐基线 OCaml 工具链
# - <variant> : (custom     , custom, optional  ): 特定 OCaml 版本或特性集

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
    buildInputs = with shared.pkgs.ocamlPackages; [
      ocaml # OCaml 编译器本身
      dune_3 # 官方推荐构建系统（OCaml 项目的事实标准）
      ocaml-lsp # 语言服务器（类型信息、跳转、补全）
      ocamlformat # 官方格式化工具（与 ocaml-lsp 深度集成）
      utop # 增强版 REPL（自动补全、历史、语法高亮）
      merlin # 编辑器辅助工具（部分编辑器仍依赖，可与 ocaml-lsp 共存）
      odoc # 文档生成器
      # ocp-indent   # 可选：传统缩进工具，ocamlformat 已覆盖大多数场景
    ];

    nativeBuildInputs = with shared.pkgs; [
      shared.pkgs.ocamlPackages.ocaml
      shared.pkgs.ocamlPackages.findlib # 库定位机制；hook 会自动设置 OCAMLPATH
      pkg-config
      gnumake # 可选：C stub / Makefile 项目
    ];

    preInputsHook = ''
      echo "[preInputsHook]: ocaml environment loading..."
    '';

    postInputsHook = ''
      echo "[postInputsHook]: ocaml environment ready."
      echo "  OCaml   : $(ocaml -version 2>/dev/null || echo 'available')"
      echo "  Dune    : $(dune --version 2>/dev/null || echo 'available')"
      echo "  LSP     : $(ocaml-lsp --version 2>/dev/null || echo 'ocaml-lsp available')"
    '';

    preShellHook = ''
      echo "[preShellHook]: entering ocaml shell..."
    '';

    postShellHook = ''
      echo "[postShellHook]: ocaml shell active."
      echo "  Tip: dune init project <name> 初始化项目；dune build / dune test 构建与测试。"
      echo "  Tip: ocamlformat -i <file> 就地格式化；项目根建议放置 .ocamlformat 配置。"
      echo "  Tip: findlib 的 hook 已自动设置 OCAMLPATH，dune 与 ocamlfind 可直接定位库。"
    '';
  };
}
