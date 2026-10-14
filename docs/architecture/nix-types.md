# nix-types 集成裁决 — 现状盘点与参考演进（2026-10-11）

> 背景：nix-types（github:Redskaber/nix-types，本仓 flake input）是
> 同作者的纯 Nix 代数数据类型库——enum 构造器 / match 穷尽分派 /
> Option / Result ADT，lib 本体零 nixpkgs 耦合（仅 `builtins.*`），
> 440 测自证。本文盘点它在 nix-config 中的既有消费面，裁决
> 「source-scopes 机械 enum 化」提案，并登记闲置能力与上游文档债。
> 证据均为一手核验（文件:行号）。

### 1. 现状：不是候选，已是类型层地基

- **input 声明**：flake.nix `nix-types.url = "github:Redskaber/nix-types"`；
  pdshell 以 `follows = "nix-types"` 钉到同一实例（注释明言防
  nix-types_2 漂移——SSOT）。
- **三层消费**（4 处一手锚点）：
  1. **enum 构造器**：`lib/shared/lang/enum.nix`
     `inherit (inputs.nix-types.lib) enum;`——platform / version /
     arch / portal / window-manager / display-manager / sound / shell /
     drive-group / editor / editor-set / terminal-set / browser-set /
     app-set / service-profile / pointer-cursor，共 16 张在役策略表
     （drive 表以注释留位），全部以 enum ADT 构造（载荷行携带
     caps 向量、策略函数、集合路由）。
  2. **Result 铁路**：`lib/shared/lang/validate.nix` 与
     `lib/shared/runtime/default.nix`
     `inherit (inputs.nix-types.lib) result;`——ok/err/andThen 在
     数据驱动的 pass 列表上组合，`unwrapOrElse throw` 是全仓唯一
     throw 边界（Err 诊断逐字成为 eval 错误）。
  3. **match 穷尽分派**：`platform/nixos/system/wm/hyprland/plugins/default.nix`
     对 shared.version（v25_11 / v26_05 必须显式回答，无 silent else）；
     `home/wm/hyprland/default.nix` 对 shared.platform（nixos 行 +
     通配兜底）。
- **回归锁定**：`tests/lib/shared/lang/` 5 文件 732 行——真实生产
  import + 锁定 rev 断言（truthfulness 纪律），nix-types 的任何
  坏 bump 在本仓 CI 求值期即被抓。
- **双源契约零冲突**：nix-types lib 不 import nixpkgs，`sameSource`
  （fn.nix）管辖的 stable/unstable 拼接与之正交。

### 2. 提案审查：source-scopes 机械 enum 化 — 驳回

提案：把 `lib/shared/runtime/default.nix` 的 source-scopes 字符串键
分派换成 `enum "nixpkgs-source" { stable = pkgs; unstable = upkgs; }` +
match。三条证据（均一手核验）：

1. **schema 默认值的词法作用域**：`nixpkgs-source ? "stable"`
   （schema.nix i18n 段）的默认值在 schema.nix 自身作用域求值；enum
   表在兄弟模块 enum.nix 中构造。schema 无法在不改 phase-1 接线的
   前提下携带 enum 实例默认值——带默认值的字段要么保持字符串，
   要么被迫 required 化（全部 host 加样板声明，违背 T4.0「默认值
   物化」的初衷）。
2. **字符串消费面**：`home/core/base/i18n.nix` 与
   `platform/nixos/system/core/base/i18n.nix` 把声明源直接插值进 sameSource
   守卫的诊断串（`${shared.i18n.nixpkgs-source}`）；enum 实例插值
   依赖 `__toString`，诊断语义改变（标签 vs 声明原文）。
3. **诊断质量回归**：`.${str}` 属性缺失 → Nix attribute-missing
   （不带合法面）；match 对非实例输入 → validateInputType throw
   （不带修复指引）。现有手写 throw 同时携带**非法值 + 合法面 +
   修复位置**三者，正是前端正断言的形态。

**裁决**：驳回机械 enum 化；落地等价微修复——诊断中的合法面改为
`builtins.attrNames source-scopes` 派生（单一事实源：新增 scope
诊断零改自动更新）。**重开条件**：nix-types 若提供
`parse`/`fromString` 桥（字符串 → 实例构造，诊断携带合法面），
本提案可按 T10.1 模式（schema 必需键 + 载荷枚举 + 穷尽分派）重开。

### 3. 已落地动作（本批 commit）

- **runtime**：source-scopes 合法面数据驱动（上述微修复）。
- **flake**：nix-types input URL 钉 rev `815fc3f…`（上游无 tag，
  `git ls-remote --tags` 空集——40-hex SHA 是唯一可钉形态），与
  9ebe543 的 action-SHA 机器契约同族：周更不再拖动 nix-types HEAD，
  升级从「惊喜」变为「刻意决定」；732 行电池 + nix-types 自身的
  440 测 checks.testSuite 是坏 bump 的双安全网。

### 4. 闲置能力登记（未来分派，非承诺）

| 能力 | 形态 | 触发场景 |
| --- | --- | --- |
| `serialize` | 实例 → flat JSON-safe（tag/typename/value） | debug 面（`nix eval .#debug`）需要 dump 平台表 / 策略表时的现成原语 |
| 多实例 match + specificity | `Red._` 优先于 `._._`，列表/attrset 双形态 | 「平台 × 版本」二维分派出现时（hyprland plugins 是一维先行例） |
| `isType` 指纹 | `__meta__.variantNames` 区分同名不同变体集 | 测试断言需要枚举同一性判等时 |

（T25 前 `lib.version` 断言曾在此表闲置——触发场景已兑现，见第 5 节落地记录。）

### 5. 上游文档债清偿与版本身份契约（T23，2026-10-12）

- **死引用修正**：原登记的 PATTERNS.md「所有者本地未 push commit
  61bc6ce」随沙箱环境重建**彻底丢失**（新 clone 对象库无此 commit、
  GitHub 侧 HEAD 仍 815fc3f、无 reflog）——该登记曾是唯一的交付存证。
  现已重写并扩展：nix-types `evolve/t23-version-identity` 分支
  两 commit（`2fd8779` PATTERNS.md 七模式 + `d973191` 版本身份，
  顺序为基座→扩展），以 web 完整包下载接口交付，push 前任何
  引用以该 patch 为准。内容相对原稿的增强：新增 Version contract
  模式（原稿成文时 `lib.version` 尚不存在）与「何时不要 enum 化」
  判例清单（本文档第 2 节裁决的知识沉淀）。
- **版本身份（T23.1，nix-types 3.6.0）**：`lib/version.nix` 单源
  `version = "3.6.0"`，`lib/default.nix` 顶层合并；第 17 号测试套件
  六法则锁定（存在性 / semver 形状 / 钉值真话纪律 / 不泄漏边界 ×3
  ——枚举类型面、实例记录、`__meta__` 均不携带）；推导名
  `nix-types-${version}` 与 demo 横幅同源（原手工 `v3.4` 落后两个
  版本）。**验证从静态升级为求值**：沙箱 rootless nix
  （`~/nixroot/nx`，2.35.2）幸存复用，446/446 真实求值绿。
- **下游断言（已落地，T25）**：owner 已 push nix-types
  （`a1a2a13`——T23 双 commit squash 采纳），本仓 lock bump
  （`815fc3f → a1a2a13`，flake.nix 钉点 + narHash 同步）且 lang 电池
  落地 version 契约断言：`lib_shared_lang_version`（第 97 号测试，
  tests/lib/shared/lang/version.nix——原登记的 96 号候选被 T24 的
  `lib_shared_overlays` 占位，顺延一位）断言
  `inputs.nix-types.lib.version == "3.6.0"`——rev 钉住「哪里」，
  version 断言钉住「什么」，坏 bump 从「三层数下游的 attribute
  missing」提前为「点名双侧的一行红」（变异检查实测：假 expected
  → throw 同时报出 lock rev / expected / observed 三方 + 双文件
  和解指引）。bump 的两文件刻意决定形态：flake.nix 钉点 + 测试
  expected——单侧漂移即红。
