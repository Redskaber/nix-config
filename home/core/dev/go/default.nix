# @path: ~/projects/configs/nix-config/home/core/dev/go/default.nix
# @author: redskaber
# @datetime: 2026-02-26
# @description: home::core::dev::go::default
# Modern Go dev environment with China-optimized networking & toolchain
# - Attrset   : (Permission , Scope , Load      )
# - default   : (readonly   , global, default   ): Minimal base env with proxy resilience
# - <variant> : (custom     , custom, optional  ): Project-specific overrides

{ pkgs, inputs, shared, dev, ... }: {
  default = {
    shell = "zsh";
    # 🌐 核心工具链（Go 1.22+ 现代标准）
    buildInputs = with pkgs; [
      go
      gopls                       # 官方 LSP（2026 已深度集成 generics 支持）
      delve                       # 调试器（支持 generics 断点）
      go-tools                    # 静态分析（含 generics 检查）
      golangci-lint               # 聚合 linter（预配置 modern 规则集）
      gofumpt                     # 严格格式化（比 gofmt 更符合 2026 社区规范）
      gotests                     # 智能测试生成
      gomodifytags                # Struct tags 管理
      impl                        # 接口实现生成
      richgo                      # 彩色测试输出（提升可读性）
    ];

    preInputsHook = ''
      echo "[preInputsHook]: go shell!"
    '';
    postInputsHook = ''
      echo "[postInputsHook]: go shell!"
    '';

    preShellHook = ''
      echo "[preShellHook]: go shell!"
    '';
    postShellHook = ''
      # ====== 代理配置 ======
      # Go 模块代理（七牛云主推 + 阿里云备用）
      export GOPROXY="https://goproxy.cn|https://mirrors.aliyun.com/goproxy/,direct"

      # SumDB 代理（避免 checksum 验证失败）
      export GOSUMDB="sum.golang.google.cn"     # 七牛云代理的 sumdb

      # ====== 现代 Go 工作流优化 ======
      export GO111MODULE="on"                   # 强制模块模式
      export GOFLAGS="-mod=readonly -trimpath"  # 只读模式 + 去路径污染
      export GOWORK=""                          # 禁用 workspace

      # ====== 项目级隔离 ======
      export GOMODCACHE="$PWD/.cache/go-mod"    # 项目专属模块缓存
      export GOBIN="$PWD/.bin"                  # 项目专属 bin 目录
      mkdir -p "$GOMODCACHE" "$GOBIN" 2>/dev/null
      export PATH="$GOBIN:$PATH"
      echo "[postShellHook]: go shell!"
    '';

  };


}


