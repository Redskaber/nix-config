# 编译器管线与分层架构 — 全景参考

> 本文是管线内容的**规范参考**：pass 逐段参考卡、分层架构 × 管线阶段对照、
> 横切维度（依赖 × 密钥 × 用户交互 × 外置配置）、
> 命名模型索引、设计不变量、变更剧本。概览图见
> [README 架构总览](../../README.md#架构总览)；各段机制散文见
> [mechanisms.md](mechanisms.md)（§0 总览 · §1–§3 管线各段深度版 · §4–§11 横切机制）。
> 两者分工：README 管速览，mechanisms 管「为什么」，本文管「一页查全」。

## 1. 管线总图（七段单向流）

仓库自比一台编译器：策略文件是源码，flake outputs 是目标码，`specialArgs`
是 ABI。全管线单向流动，无反向依赖：

```
源        shared.nix（fleet 层）· enum.nix role 表（role 层）
          · hosts/<h>/shared.nix（host 层，可选开放文件）
            ↓
Pass 1    lib/shared/lang/          前端：类型 · 枚举 · schema · 验证
（前端）                            （纯 Nix，零 pkgs）
            ↓
Pass 2    lib/shared/default.nix    中间端：三层受控合并 fleet ⊕ role ⊕ host
（合并）                            （Law F 白名单 · schema.shared 18 键再验证
                                     · hostName 强制对齐 · why 逐键溯源）
            ↓
Pass 3    lib/shared/runtime/       IR 合成：caps · pkgs/upkgs · i18nScope ·
（合成）                            homeDir · orc · pdshell · sops 三函数 ·
                                    集合展平（editors/terminals/browsers/
                                    appCategories/services）
            ↓
Pass 4    lib/shared/targets.nix    后端：readDir hosts/ 清单 → caps 查表分类
（codegen）                         → 四发射器（nixos / darwin / standalone-HM /
                                    colmena Hive）+ 两个 toplevel 投影面
            ↓
Pass 5    lib/shared/faces.nix      链接：成品装配到 flake 协议输出名
（链接）                            （flake.nix 只剩输入注册 + 一行委托）
            ↓
Pass 6    specialArgs /             装载：platform/ · home/ 模块树以
（装载）  extraSpecialArgs          { shared, inputs, … } 消费句柄
```

**编译器隐喻对照：**

| 编译器概念 | 本仓对应物 |
| ---------- | ---------- |
| 前端（词法/语法/语义检查） | `lib/shared/lang/`：enum 构造即穷尽、schema 解构校验器、validate Result 铁路 |
| 中间端（IR + 优化 pass） | 三层受控合并 + `runtime/` 句柄合成；优化如 CSE（`sharedByHost` 每主机单实例化） |
| 后端（目标码生成） | `targets.nix` 四发射器：按目标描述生成 nixos / darwin / standalone-HM / colmena Hive closure（一个策略图进，四种闭包格式出） |
| 目标描述（target triple） | `enum.platform` 行的 caps 能力向量——后续 pass 查表，绝不重词法分析 |
| 链接器（符号装配） | `faces.nix`：checks 六门聚合 / module-docs / pdsh / tests 单次构造 |
| 符号表 | 输出命名模型（Law G）——目录名 per-kind 唯一，见 §5 |

**对象结构视图（装配关系，与上图正交）：**上图按**求值时序**读——数据怎么流；
下图按**持有关系**读——谁装配谁。两图描述同一管线的两个投影：Pass 5 链接
= faces.nix 框，Pass 4 codegen = targets.nix 框 + 分类器 + 四发射器，
Pass 6 装载 = modules/specialArgs 以下；`flake.lock` 是求值的第一事实源
（锁定的输入图决定一切上游 rev）：

```
flake.lock ─▶ flake.nix（输入注册 + 一行委托）─▶ faces.nix（链接：只写 inherit）
                                    │
          ┌─────────────────────────▼──────────────────┐
          │ targets.nix — 后端工厂（策略 IR 所在地）   │
          │  shared = import ./default.nix（基实例）   │
          │  · 合并发生在 default.nix：                │
          │    fleet ⊕ role ⊕ host 覆盖（lang 主持）   │
          │  sharedByHost = genAttrs hostNames mkShared│
          │    （惰性：未强制的主机零成本）            │
          └───────┬───────────────────────┬────────────┘
    caps 查表分类 │                       │ per-host IR
    (零 if-else)  │                       │ 句柄 sharedByHost.<h>
          ┌───────▼────────┐      ┌───────▼──────────────┐
          │ 分类器         │      │ per-host IR          │
          │ nixosHosts     │      │(CSE：每主机单实例；  │
          │ darwinHosts    │      │  基表项 = 基实例句柄)│
          │ standaloneHosts│      └───────┬──────────────┘
          └───────┬────────┘              │
          ┌───────▼───────────────────────▼─────────┐
          │ 四发射器 — 一个策略图进，四种闭包格式出 │
          │ nixosSystem · darwinSystem · homeManager│
          │ colmena Hive（nodeSpecialArgs 递同款    │
          │ per-host thunk，重发射同构）            │
          └───────────────┬─────────────────────────┘
    modules = [ platform/${tag}/system|home ] + specialArgs { inputs, shared }（ABI）
                          │
          ┌───────────────▼─────────────────┐
          │ platform 门(能力声明：文件存在即│
          │ 声明)                           │──▶ hosts/<h> 事实
          │  platform/<tag>/system（系统门）│   （hardware·disk·persist
          │  platform/<tag>/home（home 门， │    由系统门挂载；deploy.nix
          │  门即 payload）                 │    归 colmena 发射器消费）
          └───────────────┬─────────────────┘
                          ▼
      home/{core,env,wm} 叶子 — 目录插值路由 · mkIf caps 门控
      · 策略载荷 .value.* · sops Result 铁路 · 外置 dotfiles
      · orc activation（各机制深度版：mechanisms.md §2·§5·§6·§8）
```

## 2. Pass 参考卡

每段一卡：位置、消费、产出、守卫（哪个测试/门钉住它）、失败模式（何时、
在哪一层、多大声）。

| # | Pass | 位置 | 消费 → 产出 | 守卫 | 失败模式 |
| - | ---- | ---- | ----------- | ---- | -------- |
| 0 | 源（三层策略链） | `shared.nix` · `enum.nix` role 表 · `hosts/<h>/shared.nix` | — → fleet 基线（身份/多数派默认/roles 注册表）+ role 形态束 + host 类键特化 | Law E（`tests/lib/shared/roles.nix`：注册表 ↔ hosts/ 双向零漂移）；`shared-roundtrip`（模板 ↔ 生成物字节等价） | 未注册的主机目录 → 加载器 throw「无 role 指派」；模板/生成物漂移 → roundtrip 门红 |
| 1 | 前端 | `lib/shared/lang/` | 源策略 → 类型系统（17 张 enum 表 + schema 解构校验器 + validate Result 铁路），零 pkgs | `lib_shared_lang_*` 7 tests（enum/caps/schema/fn/validate/version）；nix-types 版本钉（`lib_shared_lang_version`） | enum 构造越界/重复 → 构造即 throw；穷尽分派缺分支 → match throw |
| 2 | 中间端（合并） | `lib/shared/default.nix` | fleet ⊕ role ⊕ host → 受控合并结果 + `why` 逐键溯源 | Law F：role 行越界键（身份/类键）→ 合并点 throw，键名点名；`schema.shared` 18 键契约再验证（`lib_shared_lang_schema` 静态锁 functionArgs） | role 行携带 `user`/`platform` → throw 列出全部越界键；合并结果缺键 → schema 解构 eval 失败 |
| 3 | IR 合成 | `lib/shared/runtime/` | 合并结果 → 句柄：caps 解析 · pkgs/upkgs 双实例 · i18nScope · homeDir · orc/pdshell · sops 路径三函数 · 五个集合展平 | `lib_shared_lang_validate`（secret 路径 Result 铁路：declared-but-not-provided eval 期显形）；i18n 双源混装 `fn.sameSource` eval 期 throw | stable/unstable 混装输入法栈 → eval 期 loud fail（995d8c9 事故的结构性免疫）；声明而缺 blob 的 secret → eval 期 trace 引导命令（树上有 blob 后转严） |
| 4 | 后端（codegen） | `lib/shared/targets.nix` | 句柄 × hosts/ 清单 → `nixosConfigurations` / `homeConfigurations` / `darwinConfigurations` / `colmenaHive` + `hostToplevels` / `darwinToplevels` 投影 | Law G：遗留别名 `<user>-<platform>` 影子真实主机目录 → eval throw；`lib_shared_targets` 命名普查（三面键 = 清单精确相等 · 无面名携带 arch tag · hostName 逐台对齐）+ 事实普查（Law A/B/C）；`lib_shared_deploy`（colmena 发射覆盖 = nixosHosts，版本身份单源） | 别名冲突 → throw（说谎的名字，最恶劣失败模式，编译器同作用域重声明语义）；deploy.nix 挂在非 NixOS 主机 → throw「lying file」 |
| 5 | 链接 | `lib/shared/faces.nix` | 各生产端成品 → flake 协议输出名（checks 六门聚合 / api 面 / devShells / packages / formatter / export 模块） | `lib_shared_deploy`（与 faces.nix 同款实参逐字断言）；docs-ssot（pdsh 计数 = devShells 面） | 链接层只写 `inherit`——本层无独立失败模式，上游 throw 原样透传 |
| 6 | 装载 | `specialArgs` / `extraSpecialArgs` → `platform/<tag>/{system,home}` | 输出面 → 模块树求值（`{ shared, inputs, … }` 消费句柄） | module-reachability 门（home/ + platform/ 每个 default.nix 目录必须从 9 个图根可达）；platform-grammar 门（目录语法 v4 形状） | 悬空模块目录 → reachability 门红；v3 尸体形状 → grammar 门红（地址空间层直接拒绝） |

**跨 pass 不变量：** 每主机策略 IR 单实例化（`sharedByHost` 表，分类器/发射器/
命名/别名共读一张表——默认主机表项 = 基实例句柄共享）；惰性求值下未强制的
主机闭包零成本；`//` 合并永不深合并（enum 实例是 attrset，深合并腐蚀策略载荷）。

## 3. 分层架构 × 管线阶段对照

仓库的七个结构层与编译器阶段的桥接表——「层」是**磁盘组织**（职责边界），
「pass」是**求值时序**（数据流）；两者正交：shared 层装着 pass 1–5，
test 层纵切全部 pass，secret 层横切 pass 6 的运行时。

| 仓库层 | 目录 | 管线角色 | 关键约束（守卫） |
| ------ | ---- | -------- | ---------------- |
| entry | `flake.nix` | 输入注册 + 一行委托（Pass 5 成品在此登场） | 入口层零缓存身份（cache-ssot 三禁断言：标识符/URL/公钥） |
| shared | `lib/shared/` | Pass 1–5 的全部发生地（lang → default → runtime → targets → faces） | 两阶段初始化（lang 零 pkgs → runtime 注入）；每主机单实例化 |
| host-dispatch | `platform/<tag>/` | Pass 6 的门面：平台目录 = target double 的 platform 半边（arch 半边为管线值） | 目录语法 v4（platform-grammar 门）；文件存在 = 能力声明 |
| system | `platform/<tag>/system/` | 系统域模块树（core/dm/wm/…，仅 nixos · darwin · nixos-wsl 有） | system/default.nix = 系统门：入口 + 挂载 hosts facts |
| user | `home/` + `platform/<tag>/home/` | 用户域模块树（core/exp/sec/srv + env + wm） | home/default.nix = home 门，门即 payload，arch 轴退役 |
| secret | `secrets/` + `.sops.yaml` | 横切 Pass 6 运行时（initrd 解密 → /run/secrets） | 明文禁提交（CI secret 完整性阶段）；eval 宽容/部署硬失败 |
| test | `tests/` | 纵切全部 pass（6 平面 108 tests + 6 仓库卫生门 = 114 checks） | 计数锚点 docs-ssot 机器强制；新测试与锚点同 commit 旅行 |

七个结构层回答「磁盘上谁在哪」；还有四个维度**不是磁盘层，而是贯穿多层的
正交轴**——依赖、密钥、用户交互、外置配置——它们如何流经同一组 pass，
见下一节。

## 4. 横切维度 × 管线阶段（依赖 · 密钥 · 用户交互 · 外置配置）

### 4.1 依赖分层 — 47 inputs 四类角色 × pass 消费矩阵

`flake.lock` 是求值的第一事实源（对象结构视图，§1）。47 个 inputs
（计数口径 = 求值面 `attrNames`；grep `.url =` 的 46 不落文档）分四类：
上游社区 14 · 自有工具库 4 · 自有应用 flake 6 · 自有非 flake 源 23。
每个 pass 消费哪些输入，一张矩阵查全：

| Pass | 消费的输入 | 角色 |
| ---- | ---------- | ---- |
| 1 前端 | **nix-types**（版本钉：`lib_shared_lang_version`） | 类型地基——enum/match/Option/Result；零 pkgs 是它进 Phase 1 的资格 |
| 3 合成 | **pdshell**（devShell 管道句柄）· **orc**（配置树编排句柄，按 arch 解析） | runtime 注入 `shared.pdshell` / `shared.orc` 短路径 |
| 4 codegen | nixpkgs · nix-darwin · home-manager · colmena | 四发射器的引擎（nixosSystem / darwinSystem / homeManagerConfiguration / makeHive） |
| 5 链接 | pre-commit-hooks（pre-commit-check）· pdshells → devShells 面 | checks 门聚合 + devShell 面 |
| 6 装载 | sops-nix · disko · impermanence · nixos-wsl（解释器，各一行 import 注册在 platform 侧）· nixgl · nur · hyprland(+plugins) | 系统域解释器与载荷 |
| 测试（纵切） | **nmt**（Plane 5，flake=false） | HM 模块测试框架 |
| 载荷（横切） | 自有应用 flake 6（wechat · cnmplayer · unrpyc · trae · z-library · zcode） | home/env 按引用消费 |

自有四仓按管道相位正交分布——无循环依赖、无替代关系，只有自上而下单向
消费：nix-types（Phase 1 前端）→ pdshell / orc（runtime 合成）→
pdshells（faces 发射）→ nmt（tests 独占）。分层事实与共性契约全文见
[external-repos.md](external-repos.md)；逐仓依赖树见
[dependency-graph.md](dependency-graph.md)。

### 4.2 安全密钥 — 六相生命周期 × pass 映射

secret 不是一层静态文件，而是一条**声明 → 验证 → 解密 → 挂载**的跨 pass
流水：

```
TMPL（docs/tmpl/sops/ 模板）
  → KEY（age 密钥，按使用者分组）
  → RULE（.sops.yaml creation rules：路径 → 密钥组）
  → PLAIN（secrets-init 生成，明文禁提交——CI secret 完整性阶段）
  → CIPHER（sops encrypt——git 里的唯一形态）
  → /run/secrets/（sops-nix 运行时解密挂载，initrd 阶段）
```

| Pass | 密钥动作 | 守卫 |
| ---- | -------- | ---- |
| 0 源 | `shared.nix` 的 `secrets` 键声明清单 | schema.secrets 子校验器（lambda 存在性契约） |
| 3 合成 | sopsFile / sopsPath / sopsUserPath 三函数合成——**Result 铁路**：声明而缺 blob → eval 期 trace 引导命令（树上有 blob 后转严） | `lib_shared_lang_validate` |
| 6 装载 | sops-nix 解释器注册（platform 侧一行 import）→ initrd 解密 → /run/secrets | 明文禁提交（CI）；eval 宽容 / 部署硬失败 |

（Pass 1–2、4–5 不涉密：类型检查/合并/闭包装配/链接均零密钥。）
深度版见 [mechanisms.md §5](mechanisms.md#5-安全层--sops--age分层管理)；
按情景的查阅手册见 [secrets/scenarios.md](../secrets/scenarios.md)。

### 4.3 用户交互 — 用户面 × 管线路径

「用户摸得到的一切」都是策略驱动，经同一管线流出：

| 用户面 | 载体 | 管线路径 |
| ------ | ---- | -------- |
| 登录 shell 与全局工具 | `home/env/base`（clang · rustc · python · node · valgrind…始终可用，不依赖 devShell） | Pass 3 句柄 → Pass 6 home 门 |
| 按语言 devShell | `home/env/dev/<lang>/`（每文件一 attrset，key = shell 名）→ pdshell → devShells 面 | Pass 3 句柄 → Pass 5 面（`nix develop` / `just devenv-*`） |
| 窗口管理器 | `home/wm`（gnome · hyprland · niri · none；enum `window-manager` 行携带 portal 策略） | Pass 1 enum → Pass 6 mkIf caps 门控 |
| 主题（wallust 跨应用注入） | orc activation hook（含 waybar 主题重载） | Pass 3 `shared.orc` → Pass 6 activation |
| AI CLI 工具 | `home/core/exp/sys/ai/`（claude-code · opencode · gemini-cli · kiro-cli · cursor-cli · pi-coding-agent） | Pass 6 用户域模块树 |
| 应用集 | editors / terminals / browsers / appCategories 展平 | Pass 3 五集合展平 → Pass 6 叶子消费 |

深度版见 [mechanisms.md §4](mechanisms.md#4-开发环境管道--pdshell)（pdshell）·
[§6](mechanisms.md#6-配置编排器--orcconfigurationorchestrator)（orc）·
[§7](mechanisms.md#7-用户环境层--homeenv)（用户环境层）。

### 4.4 外置纯配置仓库 — ×22 flake=false 的消费路径

22 座 `*-config` 仓库是**纯数据源**（不参与 flake 求值）：flake.lock 锁
rev → Home Manager 激活时经 orc 编排写入 `~/.config/<app>/`。双安全网
正交：**lock 钉 WHERE**（可复现地从哪取）· **tests 钉 WHAT**（取来的行为
对不对）——bump 只动 lock 时，行为破坏由测试红报警；行为未变而源移动时，
lock 保持绿。清单与共性契约见 [external-repos.md](external-repos.md)；
深度版见 [mechanisms.md §8](mechanisms.md#8-外部配置仓库flakefalse-inputs)。

## 5. 命名模型（符号表语义，索引）

目录名是唯一的命名身份来源；arch 永不入名（管线值，非地址）；管线只在
nixosConfigurations 上铸造一个合成名（遗留别名），且由 Law G 守卫永不影子
真实主机。完整裁决（消费动词语义 · 跨领域坐标 · Law G 全文）见
[mechanisms.md §3](mechanisms.md#3-分发层--targetsnix-目标工厂)。

| 输出面 | 键 | 唯一性来源 |
| ------ | -- | ---------- |
| `nixosConfigurations` | `<目录名>` + 遗留别名 `<user>-<platform>` | 目录名 per-kind 唯一；别名 Law G 守卫 |
| `homeConfigurations` | `<user>@<目录名>` | 目录名 × 用户名（host 层可覆写 user，面跟随） |
| `darwinConfigurations` | `<目录名>` | 目录名 |
| `colmenaHive.nodes` | `<目录名>`（= nixosHosts） | 目录名（Law D 锁定发射覆盖） |

## 6. 设计不变量

全管线生效的机器强制不变量（每条：内容 → 为什么 → 守卫）：

1. **单向流** —— 源 → 前端 → 合并 → 合成 → codegen → 链接 → 装载，
   无反向依赖；模块树永不 import flake.nix / faces.nix。（管道形状本身；
   module-reachability 门图游走。）
2. **受控合并，永不深合并** —— `//` 后层胜前层；enum 实例是 attrset，
   深合并腐蚀策略载荷。（Law F throw · schema 解构。）
3. **hostName 强制对齐** —— 加载器钦定目录名，任何层都赢不了它；
   硬件路由（`../hosts/${shared.hostName}`）因此不可能挂错机器。
   （`lib_shared_targets` 普查第 6 项。）
4. **每主机单实例化（CSE）** —— `sharedByHost` 单表 + 句柄传递；
   默认主机表项 = 基实例。（求值纪律，T5.10；非惰性重复求值即性能回归。）
5. **文件存在 = 声明** —— deploy.nix/disk.nix/persist.nix 的存在即
   「此主机携带该事实」；缺席即默认。（数据 + 解释器分离路线，
   T5.12–T5.14；Law B/C 巡检尸体文件。）
6. **能力归平台结构树，数据归 hosts/** —— 解释器注册在 platform/ 侧
   （disko/impermanence/sops-nix 各一行 import），机器事实在 hosts/。
   （目录语法 v4 + platform-grammar 门。）
7. **身份 SSOT 按值分发** —— fleet cache 身份单源 `lang/const.nix`，
   能求值的面按值消费，不能的持钉死字面镜像，入口层法定沉默。
   （cache-ssot 门三禁断言。）
8. **入口层沉默** —— flake.nix 只做输入注册 + 一行委托；任何装配逻辑
   回流入口层即架构回归。（R31 重构的终态；faces.nix 头注契约。）

## 7. 变更剧本（管线视角）

**加一台主机**：`shared.nix` roles 注册表一行（Pass 0）+ `mkdir hosts/<name>`

+ 类键 `shared.nix`（Pass 0）。Pass 1–6 全部自动：清单发现 → 单实例化 →
分类 → 发射 → 面。零 flake.nix 改动；Law E 双向零漂移钉死注册表与目录。

**加一个平台**：`platform/<tag>/{system,home}/` 门目录（Pass 6）+
`enum.platform` 一行 caps 向量（Pass 1）。发射器经 `platform/${tag}` 插值
自动路由；platform-grammar 门校验目录形状。

**加一个角色形态**：`enum.role` 表一行策略束（Pass 1）。注册表即刻可指派；
Law F 白名单保证束内只有策略键。

**加一个测试**：`tests/` 对应平面注册（nixosTest runner）。计数锚点
（README/test-matrix）与测试同 commit 旅行——docs-ssot 门红即漂移报警。
env/dev 语言目录与测试 1:1（每语言一目录一测试，R14 补齐闭合）。

**换 fleet 缓存身份**：改 `lang/const.nix` SSOT 一处（Pass 1）；
字面镜像（CI workflows · cachix.just · cache.md 散文）同 commit 手改，
cache-ssot 门对账。

**迁移硬件事实**：`just hardware-migrate`（facter 报告 + 接线翻转 +
legacy 退役）；终态由 `lib_shared_targets` 事实普查锁定。

---

*本文与 [mechanisms.md](mechanisms.md) 同 commit 演进；发现两者漂移即是
文档债，修一处必查另一处。*
