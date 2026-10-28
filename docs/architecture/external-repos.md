# 外置仓库分层分类 — 47 inputs 的四类角色与共性契约（2026-10-16）

> 背景：flake.nix 的 47 个 inputs 不是一张平等的平铺清单——它们分属
> 四类角色，其中同作者的四座工具仓库（nix-types / pdshell /
> configuration-orchestrator / nmt）各自占据不同的管道层。本文回答
> 「每座外置仓库处于哪一层、为什么、遵循哪些共性契约」；各仓的
> 机制内幕在各自专文（见文末交叉引用），本文只管分层事实与契约。
> 证据均为一手核验（文件:行号）。

### 1. 分类总表（47 inputs = 求值面 attrNames）

| 类别 | 计数 | 成员 | 消费层 |
| --- | --- | --- | --- |
| 上游社区 | 14 | nixpkgs（stable）· nixpkgs-unstable（第二实例，`shared.upkgs`）· nixgl · nur · home-manager · sops-nix · nix-darwin · disko · impermanence · nixos-wsl · colmena · hyprland · hyprland-plugins · pre-commit-hooks | 各层按需（依赖图见 [dependency-graph.md](dependency-graph.md)） |
| 自有工具库 | 4 | nix-types · pdshell · configuration-orchestrator · nmt | §2 逐仓裁决 |
| 自有应用 flake | 6 | wechat · unrpyc · cnmplayer · trae · z-library · zcode | home/env 按引用消费 |
| 自有非 flake 源 | 23 | commit-config（提交工具链）+ 22 × `*-config`（dotfiles 外置：fcitx5 / nvim / emacs / kitty / hypr / waybar / …，全量清单见 README §目录结构 第 8 行） | orc 编排进 home 闭包 |

**47 vs 46 的计数口径**：README 锚点句与 docs-ssot 门求值的是
`builtins.attrNames inputs`（47）；文本 grep `.url =` 只数到 46——
`hyprland-plugins` 是纯 follows input（无 `.url`，只携带
`inputs.hyprland.follows`，与 hyprland 插件生态共享同一棵 nixpkgs
实例）。两个数字都对，口径不同；仓库内引用一律以 **47**（求值面/
锚点口径）为准，grep 口径的数字不落文档。

**四类角色的判别式**（一个 input 落在哪类，看三问）：
是否同作者维护（→ 自有）；是否暴露 `lib`/`modules` 供本仓**架构性**
消费（→ 工具库），还是只作为**载荷**进闭包（→ 应用 flake）；是否
需要 flake 求值（`flake = false` 的 24 个里，nmt 与 commit-config
是工具/工具链，其余 22 个 `*-config` 是纯数据源——README 第 8 行
「×22」即指后者，不含 nmt 与 commit-config）。

### 2. 自有工具库的分层（四仓四层，一层一仓）

四座仓库按管道相位正交分布——没有两仓共享同一层职责，因此没有
循环依赖与替代关系，只有自上而下的单向消费：

```
lang 前端（Phase 1，无 pkgs）        nix-types
        ↓ 类型/ADT 供给
runtime（IR 合成，按 arch 解析）    pdshell（devShell 面）
                                    orc（配置树编排面）
        ↓ shared.* 短路径注入
faces（链接层）                     pdshells → devShells 输出
tests（Plane 5，零 VM）             nmt（模块系统测试框架）
```

#### 2.1 nix-types — lang 前端的类型地基（Phase 1）

- **是什么**：纯 Nix 代数数据类型库——enum 构造器 / match 穷尽分派 /
  Option / Result ADT，lib 本体零 nixpkgs 耦合（仅 `builtins.*`），
  自带版本身份断言（`lib.version`）。
- **为何在这一层**：lang 阶段先于 pkgs 存在（两阶段初始化的前端），
  策略表的 enum 化与 Result 铁路都必须在求值早期可用——nix-types 的
  零依赖性使其成为唯一能进 Phase 1 的外部库。
- **消费面**（一手锚点）：`lib/shared/lang/tools.nix:24`（短别名
  `nt` 注册）→ `lang/enum.nix:9`（17 张策略表，含 role 角色表）、`lang/validate.nix:49`
  - `runtime/default.nix:22`（Result 铁路）、`platform/nixos/system/wm/hyprland/plugins/default.nix:18`
  - `platform/nixos/home/wm/hyprland/default.nix:88`（match 穷尽分派）。
- **测试安全网**：`tests/lib/shared/lang/`（enum/validate 的行为
  契约）+ `tests/lib/shared/lang/version.nix`（版本身份契约）。

#### 2.2 pdshell — runtime 注入 + faces 发射的 devShell 管理器

- **是什么**：管道式 devShell 管理器——`mk-pdshell` 七阶段 FSM +
  `pdshells` 目录加载器；ContextPhase 建于其姊妹仓 nix-types 的
  enum 之上。
- **为何在这一层**：devShell 是「运行时才定形」的面（依赖 pkgs 与
  用户策略 IR），且其输出面（flake 的 `devShells` attrset）在链接层
  faces.nix 发射——pdshell 横跨 runtime 与 faces 两相，但类型供给
  全部来自 nix-types（follows 钉死）。
- **消费面**：`lang/tools.nix:31`（`pdshell-raw` 注册）→
  `runtime/default.nix:99`（注入 `shared.pdshells`）→
  `faces.nix:62`（`pdsh = shared.pdshells { … }`，单次构造两消费：
  devShells 输出 + docs-ssot 门计数）；定义数据在
  `home/env/dev/`（`shared.nix` 的 `devDir`）。
- **测试安全网**：`tests/lib/shared/pdshell.nix`（五组契约：目录
  加载、FSM 相位、参数记录原文断言）。

#### 2.3 configuration-orchestrator（orc）— runtime 按 arch 解析的配置树编排器

- **是什么**：纯 Nix 配置树编排库——发现 → include-intent 策略 →
  emitter 分派（symlink / copy / text）；`mergeHomeFiles` 对
  22 个 `*-config` 外置 dotfiles 仓的树做声明式合成。
- **为何在这一层**：其 lib 是 **arch 限定**的（`lib.${system}`），
  只能在 runtime 阶段按 `shared.arch.tag` 解析——这也是它注册为
  `orc-raw`、由 runtime 重发布为 `shared.tools.orc` 的原因（短路径
  表见 tools.nix 头注）。
- **消费面**：`lang/tools.nix:28`（`orc-raw`）→ `runtime/default.nix:77`
  （arch 解析）→ home 层 7 处主题栈（hyprland / quickshell / waybar /
  swaync / rofi / cava / kitty——`platform/nixos/home/wm/hyprland/default.nix:46`
  为代表：`shared.orc.mergeHomeFiles (shared.orc.listFilesRecursive inputs.hypr-config "")`）。
- **测试安全网**：`tests/` 的 orc 行为测试 + orc-guard（include
  非空选不中即 eval 失败的守卫契约）。
- **命名裁决**：flake input 全名 `configuration-orchestrator`，仓内
  通行短名 `orc`——映射关系只在此处与 tools.nix 注释中声明。

#### 2.4 nmt — tests 层独占的模块测试框架（flake = false）

- **是什么**：rycee/nmt 的 GitHub mirror fork（sourcehut 主源对
  Nix fetchers 返回 403，故走 fork）；Home Manager 模块系统的测试
  框架（包擦洗 + 目录快照断言）。fork delta 有二：grep 断言在
  needle 前传 `--`（防选项样式的 needle 被当作 flag）；自带回归
  电池。
- **为何在这一层**：`flake = false`——nmt 是**测试时**依赖，不进
  任何主机闭包；消费点全仓唯一：`tests/nmt/default.nix:87`（Plane 5，
  16 tests，`buildHomeManagerTest` 自实现，零 VM）。
- **测试安全网**：nmt 自身的自测电池 + 本仓 `tests/nmt/` 的
  16 个测试即其消费证明。

### 3. 共性契约（四仓共享的接入纪律）

1. **短路径注册（tools.nix 唯一门）**：所有工具库接入必须经
   `lib/shared/lang/tools.nix` 注册——配置文件写
   `shared.tools.<alias>.<api>`，绝不直写
   `inputs.<long-name>.lib.<api>`。这保持配置文件与 flake input
   命名解耦：input 改名/换源（如 nmt 换 mirror）只动一处。
2. **follows SSOT 链**：pdshell 的 nix-types 以
   `follows = "nix-types"` 钉到本仓的同一实例——两仓的类型
   ADT 永远同源，不会出现 `nix-types_2` 的双实例漂移。自有工具
   库之间的依赖一律 follows，不允许独立 lock。
3. **双安全网（lock 钉 WHERE，测试钉 WHAT）**：flake.lock 的 rev
   回答「从哪里取」（可复现）；tests/ 的契约测试回答「取来的东西
   行为是否符合预期」（可演进）。bump 只改 lock 时，若新 commit
   破坏行为契约，测试红；行为没变而来源变了，lock 绿——两个安全
   网正交，缺一不可。
4. **沙箱参考副本 ≠ lock 消费**：开发沙箱里克隆的 `~/nix-types`、
   `~/nmt`、`~/orc`、`~/pdshell` 工作副本是**读参考**（裁决与
   文档取证用）；仓库实际消费的永远是 flake.lock 钉住的 rev。
   参考副本领先 lock 是常态（见 nmt：本地 HEAD 领先 lock 一个
   commit）——领先量是否 bump 由 owner 裁决，文档注记待决态。

### 4. bump 纪律

- **何时 bump**：上游有需要的能力/修复时；不主动追 HEAD（工具库
  的价值在稳定契约，不在新潮）。
- **bump = lock + 测试同 commit**：`nix flake update <input>` 后
  跑全量门（六卫生门 + 平面测试），绿了才提交——双安全网的第 3
  条契约在此兑现。
- **fork 仓（nmt）额外一步**：先在 fork 仓验收（自测电池绿），
  re-sync upstream 的节奏由 fork 仓自己的文档裁决；本仓只关心
  mirror 的 rev 稳定性。

### 交叉引用

- 类型系统机制与裁决史：[nix-types.md](nix-types.md)
- orc / pdshell 的机制内幕：[mechanisms.md](mechanisms.md)（§4 / §6）
- nmt 完全指南：[../tests/nmt.md](../tests/nmt.md)
- 依赖图（上游社区面）：[dependency-graph.md](dependency-graph.md)
