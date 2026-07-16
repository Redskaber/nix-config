# NMT (NixOS Module Tests) 完全指南：从零到精通

> [nmt test](https://deepwiki.com/search/nixos-homemanager-nmt-test-fra_5995e254-423c-4042-9e48-b13b5703b302)

## 1. 什么是 NMT？

NMT (NixOS Module Tests) 是一套专为 **NixOS 模块系统** 设计的轻量级测试框架。它的核心理念是 **“包擦洗”（Package Scrubbing）**：在测试评估阶段，用占位符字符串（如 `@packageName@`）替换实际的软件包（Derivation），从而避免触发昂贵的包构建流程。这使得测试能够**快速验证模块的配置逻辑、生成文件和 systemd 单元**，而无需实际下载或编译任何软件。

你可以把 NMT 视为 **NixOS 模块的“单元测试”框架**。它与 NixOS 传统的集成测试截然不同：

| 特性         | NMT (模块测试)         | NixOS 集成测试 (VM 测试)        |
| ------------ | ---------------------- | ------------------------------- |
| **测试目标** | 模块配置逻辑、生成文件 | 完整系统行为、服务交互          |
| **构建开销** | 极低（不构建包）       | 高（需构建/下载包，启动虚拟机） |
| **运行速度** | 快（秒级）             | 慢（分钟级）                    |
| **关注点**   | 配置正确性             | 系统集成正确性                  |

NMT 最初是 Home Manager 项目开发的，但其设计具有通用性，**任何使用 Nixpkgs 模块系统的项目都可以使用**。

## 2. 核心原理：包擦洗 (Package Scrubbing)

### 2.1 为什么需要包擦洗？

在 Nix 模块测试中，如果你引用一个包路径（例如 `${pkgs.i3lock}/bin/i3lock`），Nix 通常会尝试构建或下载该包。对于测试模块配置逻辑而言，这既不必要也极其耗时。

### 2.2 `scrubDerivation` 函数

NMT 通过递归函数 `scrubDerivation` 解决此问题。它遍历属性集，并将每个 Derivation 的 `outPath` 替换为占位符字符串 `"@packageName@"`，同时阻止实际构建。其关键属性映射如下：

| 属性                  | 目的         | 值                         |
| --------------------- | ------------ | -------------------------- |
| `buildScript`         | 阻止实际构建 | `abort "no build allowed"` |
| `outPath`             | 占位符字符串 | `"@${lib.getName value}@"` |
| `outputSpecified`     | 停止输出遍历 | `true`                     |
| `__spliced.buildHost` | 保留输入用法 | 原始 derivation            |

例如，`pkgs.i3lock` 会被替换为 `"@i3lock@"`，从而完全绕过构建。

### 2.3 白名单系统

某些基础包（如 `coreutils`, `jq`, `bash` 等）在测试中需要**真实执行**（例如用于执行激活脚本或 shell 配置）。这些包会被加入白名单以跳过擦洗：

```nix
whitelist = let
  inner = _self: _super: {
    inherit (pkgs)
      coreutils crudini jq desktop-file-utils diffutils
      findutils glibcLocales gettext gnugrep gnused
      shared-mime-info emptyDirectory babelfish fish lndir;
  };
in outer;
```

### 2.4 Darwin 特殊处理

macOS (Darwin) 系统的 `stdenv` 更复杂，需要专门的擦洗列表。Darwin 测试会导入一个单独的 `darwinScrublist.nix`，其中包含针对 macOS 特定软件包的擦洗定义。

## 3. 环境搭建

### 3.1 获取 NMT

NMT 作为一个独立库存在。Home Manager 通过 `fetchTarball` 引入：

```nix
nmtSrc = fetchTarball {
  url = "https://git.sr.ht/~rycee/nmt/archive/v0.5.1.tar.gz";
  sha256 = "0qhn7nnwdwzh910ss78ga2d00v42b0lspfd7ybl61mpfgz3lmdcj";
};
```

也可以通过 Nixpkgs 安装（实验性）：

```bash
nix-env -iA nixpkgs.nix-lib-nmt
```

### 3.2 基本项目结构

Home Manager 的测试基础设施位于 `tests/` 目录下：

```
tests/
├── default.nix          # 测试入口，定义擦洗逻辑、模块集合和测试发现
├── modules/             # 模块测试用例（按类别组织）
│   ├── programs/        # 可自动发现
│   └── services/        # 可自动发现
├── integration/         # 集成测试（NixOS/standalone）
│   ├── default.nix
│   ├── nixos/           # 基于 NixOS 的集成测试
│   └── standalone/      # 独立集成测试
├── lib/                 # 测试辅助库
├── asserts.nix          # 自定义断言（警告与断言校验）
├── big-test.nix         # 大型测试标记
├── stubs.nix            # 包桩定义
└── tests.py             # 测试运行辅助脚本
```

### 3.3 `tests/default.nix` 关键结构

测试套件的入口文件定义了核心基础设施，包含以下关键部分：

1. **引入 NMT 框架** (`nmtSrc`)
2. **定义包擦洗核心逻辑** (`scrubDerivation`, `scrubDerivations`)
3. **配置白名单与 Darwin 特殊处理** (`whitelist`, `darwinScrublist`)
4. **生成清洗后的 nixpkgs 实例** (`scrubbedPkgs`)：在 Linux 上遍历并擦洗所有包，再应用白名单；在 Darwin 上使用专门的擦洗列表
5. **加载待测试的模块**：`modules = import ../modules/modules.nix { ... }`
6. **注入测试配置**：如阻止真实 nixpkgs 模块工作、固定用户名与家目录等
7. **测试发现**：显式列出核心测试模块，并自动扫描 `modules/programs` 和 `modules/services` 下的所有目录

## 4. 编写你的第一个 NMT 测试

### 4.1 测试文件基本模板

每个测试文件是一个 Nix 表达式，包含一个模块配置和一组 `nmt.script` 断言。以 ledger 为例：

```nix
{ config, lib, pkgs, ... }:

{
  # 模块配置部分
  programs.ledger = {
    enable = true;
    settings = {
      sort = "date";
      strict = true;
    };
  };

  # 测试断言部分
  nmt.script = ''
    assertFileExists home-files/.config/ledger/ledgerrc
    assertFileContent home-files/.config/ledger/ledgerrc \
      ${builtins.toFile "ledger-expected-settings" ''
        --sort date
        --strict
      ''}
  '';
}
```

### 4.2 测试组织与发现

测试文件需放置在约定的目录结构中，NMT 会自动发现：

```
tests/modules/<category>/<module>/<test-name>.nix
```

例如：

- `tests/modules/programs/ledger/ledger.nix`
- `tests/modules/services/screen-locker/basic-configuration.nix`

每个模块目录下需要一个 `default.nix` 来导出测试。

### 4.3 常用断言函数

NMT 提供了一组用于检查生成文件的断言函数：

| 函数                                    | 用途                   | 示例                                     |
| --------------------------------------- | ---------------------- | ---------------------------------------- |
| `assertFileExists <path>`               | 验证文件存在           | `assertFileExists home-files/.zshrc`     |
| `assertPathNotExists <path>`            | 验证路径不存在         | `assertPathNotExists home-files/.bad`    |
| `assertFileRegex <path> <regex>`        | 检查文件内容匹配正则   | `assertFileRegex $file 'pattern'`        |
| `assertFileNotRegex <path> <regex>`     | 验证文件**不**匹配正则 | `assertFileNotRegex $file 'bad-pattern'` |
| `assertFileContent <actual> <expected>` | 精确比对文件内容       | `assertFileContent $actual $expected`    |

#### 4.3.1 `assertFileContent` 用法详解

此断言用于精确验证文件内容。期望内容可以内联定义，也可以从外部文件导入：

```nix
nmt.script = ''
  # 内联期望内容
  assertFileContent home-files/result.txt ${
    pkgs.writeText "expected.txt" ''
      This is the expected content
      line 2
    ''
  }

  # 从文件导入期望内容
  assertFileContent home-files/result.txt ${./expected-result.txt}
'';
```

### 4.4 使用 `test.stubs` 和 `test.stubOverlays` 进行包桩

NMT 提供了两层桩机制：

1. **声明式桩 (`test.stubs`)**：用 `mkStubPackage` 替换指定名称的包，桩包的 `outPath` 默认为 `@name@`，并可指定版本、构建脚本等属性。
2. **编程式桩 (`test.stubOverlays`)**：直接修改包集（类似 overlay），可精细控制桩的行为。该选项是内部选项，由 `test.stubs` 和 `test.unstubs` 自动生成。

```nix
# 声明式桩：简单替换
test.stubs.my-package = { name = "my-package"; };

# 编程式桩：使用 overlay 进行更复杂的替换
test.stubOverlays = [
  (self: super: {
    my-package = pkgs.writeScriptBin "my-package" ''
      #!/bin/sh
      echo "stub"
    '';
  })
];
```

### 4.5 平台特定测试

NMT 支持根据平台过滤测试：

```nix
{ config, lib, pkgs, ... }:

{
  services.xserver.enable = lib.mkIf pkgs.stdenv.isLinux true;

  nmt.script = lib.mkIf pkgs.stdenv.isLinux ''
    assertFileExists home-files/.xsession
  '';
}
```

### 4.6 Big Tests 和 Legacy IFD

**大测试（Big Tests）**：为了快速开发迭代，耗时较长的测试可以标记为 "big test"。默认情况下启用，但可通过 `enableBig` 参数控制。

**Legacy IFD**：对于仍在使用 "Import From Derivation" 的遗留代码，可以启用支持：

```nix
{ config, lib, pkgs, ... }:
{
  test.enableLegacyIfd = true;
}
```

该选项通过 `enableLegacyIfd` 参数传递给测试入口。

### 4.7 自定义断言扩展（警告与断言）

Home Manager 在 `tests/asserts.nix` 中提供了一套扩展断言，用于验证模块产生的**警告**和**断言**消息。通过 `test.asserts.warnings.enable` 和 `test.asserts.assertions.enable` 打开后，它会自动收集消息并生成实际内容文件，再与期望列表对比。

```nix
test.asserts = {
  warnings.expected = [ "This is a warning" ];
  assertions.expected = [ "Assertion failed: ..." ];
};
```

## 5. 测试执行与工作流

### 5.1 本地运行测试

最基本的运行方式：

```bash
nix-build tests/default.nix
```

这将评估所有测试。也可以只构建特定测试：

```bash
nix-build tests/default.nix -A tests.modules.programs.ledger.ledger
```

Home Manager 还提供了一个 Python 测试运行器 `tests/tests.py`，用于更灵活地执行测试。

### 5.2 测试输出与调试

当测试失败时，你会看到类似以下输出：

```
Error: assertion failed:
  assertFileExists home-files/.ledgerrc
  File does not exist.

TESTED: /nix/store/...-test-ledger-ledger

Hint: look at the TESTED path to inspect the generated output.
```

可以进入 `$TESTED` 目录查看实际生成的文件进行调试：

```bash
ls $TESTED/home-files
```

### 5.3 CI/CD 集成

Home Manager 的 CI 使用 GitHub Actions，并实现了智能测试分块：

- **路径过滤**：使用 `dorny/paths-filter` 仅运行与变更文件相关的测试。
- **测试分块**：将测试集划分为多个块并行执行，每块约 50 个测试。每个块暴露为独立的包（如 `test-chunk-1`, `test-chunk-2`），可用 `nix build ./tests#test-chunk-1` 单独构建。

## 6. 进阶主题

### 6.1 集成测试（Integration Tests）

Home Manager 在 `tests/integration/` 目录下提供了集成测试，分为基于 NixOS 的测试和独立测试。这些测试用于验证模块在更真实环境下的行为，与 NMT 的快速模块测试互为补充。

### 6.2 测试维护者自动化

Home Manager CI 包含自动分配审查者的功能。它通过分析被更改模块的 `meta.maintainers` 字段来实现，使用 `lib/nix/extract-maintainers.nix` 提取维护者信息，再通过 Python 脚本编排流程。

## 7. 最佳实践总结

1. **保持测试小而专注**：每个测试应该只验证一个特定功能或配置选项。
2. **使用桩（Stubs）隔离外部依赖**：避免测试因外部服务不可用而失败。
3. **优先验证生成文件内容**：NMT 的核心优势是文件内容检查，充分利用 `assertFileContent` 和 `assertFileRegex`。
4. **为新增模块编写测试**：在添加新模块时，同时编写对应的测试用例。
5. **利用平台过滤**：确保测试只在目标平台上运行，避免跨平台误报。
6. **注意白名单维护**：如果测试需要真实执行某个包，记得将其添加到白名单。
7. **遵循命名约定**：测试文件应按 `tests/modules/<category>/<module>/<test-name>.nix` 放置。
8. **利用 `assertFileContent` 的精确性**：对于配置文件，使用精确内容比对确保完全符合预期。

## 8. 常见问题解答

**Q: NMT 与 Nixpkgs 的 `lib.debug.runTests` 有何不同？**
A: `runTests` 用于测试纯 Nix 函数（库代码），而 NMT 专为模块系统设计，能验证模块评估结果和生成的文件。

**Q: 如何测试需要真实构建的复杂场景？**
A: 对于需要完整系统交互的测试，应使用 NixOS VM 集成测试；NMT 仅用于模块配置逻辑验证。

**Q: NMT 可以用于非 Home Manager 项目吗？**
A: 可以。NMT 是一个独立的库，任何使用 Nixpkgs 模块系统的项目都可以集成。

**Q: 测试运行失败时如何调试？**
A: 检查 `$TESTED` 环境变量或失败输出中的路径，直接查看该目录下的生成文件。

**Q: 为什么我的测试触发了包构建？**
A: 可能使用了未经擦洗的包路径，或该包不在白名单中。检查是否通过 `${pkgs.xxx}` 直接引用。

## 9. 参考资源

- [NMT 源代码仓库](https://git.sr.ht/~rycee/nmt)
- [Home Manager 测试目录](https://github.com/nix-community/home-manager/tree/master/tests)
- [NMT Testing Framework 深度文档](https://deepwiki.com/nix-community/home-manager/5.1-nmt-testing-framework)
- [Home Manager CI/CD Pipeline](https://deepwiki.com/nix-community/home-manager/5.2-cicd-pipeline)
- [NixOS 集成测试教程](https://nix.dev/tutorials/nixos/integration-testing-using-virtual-machines.html)

---

本教程基于 NMT v0.5.1 以及 Home Manager 主分支的测试基础设施编写。随着项目发展，具体实现可能有所变化，建议以最新源代码为准。
