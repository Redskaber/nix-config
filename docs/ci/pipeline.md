# CI/CD 深度手册 — 缘起、本地预检与部署流

> 本文收纳 README「CI/CD 完整执行流」节的深度部分（T13.1 分层重构时迁出）：
> 为什么需要 CI/CD、本地预检清单、部署工作流、世代管理与回滚、自动化更新。
> 流水线全景图与缓存策略见 [README](../../README.md#cicd-完整执行流)。

### 为什么 Nix 配置需要 CI/CD

每次变更 nix-config 都等价于声明一个新的系统状态。CI 的核心价值：

1. **求值检查** — 捕获 Nix 语法/类型错误（早于 nixos-rebuild 失败）
2. **深层求值** — 面分片强制（T15.1）：api 信封 + 逐主机 toplevel drvPath + 杂项 checks + 完备性对账（全部 97 checks 必须被平面或杂项清单拥有；单进程 `nix flake check` 因内存累积地板已退役）
3. **Secret 完整性 + 供应链** — 验证加密文件结构正确，`secrets/plan/` 未被提交；
   全部 GitHub Actions 引用钉版为 40-hex commit SHA（T16.1 机器契约：
   未钉版引用在 Security Audit 腿 fail-fast 红灯，上游 tag 被篡改不影响本流水线）
4. **测试覆盖** — 95 tests 覆盖 nixos/home/lib/integration/nmt 平面
5. **自动更新** — 每周日自动更新 flake inputs 并开 PR

---

### 本地预检清单（push 前）

```bash
# 1. 静态检查
nix run nixpkgs#statix -- check .

# 2. 结构验证（无构建，无 sopsFile 触发）
nix eval .#nixosConfigurations --apply builtins.attrNames --json
nix eval .#homeConfigurations  --apply builtins.attrNames --json
nix eval .#checks.x86_64-linux --apply builtins.attrNames --json

# 3. nmt 平面（最快，< 30s，无 QEMU）
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  --json | python3 -c "import sys,json; [print(c) for c in json.load(sys.stdin)]" \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" --no-link

# 4. devShell dry-run（逐成员，面 attrNames——T18.1）
for s in $(nix eval .#devShells.x86_64-linux --apply builtins.attrNames --json \
  | python3 -c 'import json,sys; print(" ".join(json.load(sys.stdin)))'); do
  nix build ".#devShells.x86_64-linux.\"$s\"" --dry-run --no-link || exit 1
done

# 5. secret 文件验证
find secrets/chipr -name "*.yaml" | xargs grep -L "^sops:" 2>/dev/null \
  && echo "ERROR: plaintext files found" || echo "OK"
```

### 部署工作流

```
开发机 (本地)                        生产机 (NixOS)
    │                                      │
    ├── edit *.nix                         │
    ├── nix eval ... (structure check)     │
    ├── git push → CI (GitHub Actions)     │
    │       └── 7 stage passes             │
    │                                      │
    └── [CI Pass]                          │
        │   cd /etc/nix-config             │
        │   git pull                       │
        │                                  │
        │   just nixos-switch nixos        │  # => sudo nixos-rebuild switch --flake .#nixos
        │                                  │
        │   just home-switch nixos         │  # => home-manager switch --flake .#kilig@nixos
        │                                  │
        └── systemctl status sops-*        │
            just secret-get mongodb        │
```

### 世代管理与回滚

```bash
# 列出可用系统世代
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# 回滚到上一代
sudo nixos-rebuild switch --rollback

# 回滚到指定世代
sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation <N>
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

### 自动化更新

每周日 UTC 03:00，`.github/workflows/update-flake.yml` 自动：

1. `nix flake update` 更新所有 inputs；随后将 nixpkgs 重新钉到
   `nixos-26.05` **渠道快照** rev（`channels.nixos.org` 公布的
   git-revision——Hydra 已完整构建、cache.nixos.org 全量可替代；
   见下方事故裁决 #2）
2. 生成 `flake.lock` diff 摘要
3. 开 PR（branch: `automation/update-flake-inputs`，label: `dependencies automated`）

### 事故裁决记录 — run 38085235502（2026-10-11 审计）

三个独立根因，全部按「证据 → 裁决 → 修复」落地：

1. **nixos_core_srv_db_postgresql 竞态（真失败，测试侧）**：26.05 上游把
   `initialScript` / `ensureDatabases` / `ensureUsers` 从主服务的 postStart
   挪进独立 oneshot `postgresql-setup.service`（`after = postgresql.service`）。
   测试只 `wait_for_unit("postgresql.service")` 就单发断言 DB 存在——断言
   落在 setup 单元的 `CREATE DATABASE` 之前（失败快照：`\l` 只剩
   postgres/template0/template1）。**裁决**：修测试——门禁改为
   `wait_for_unit("postgresql-setup.service")`，首个断言降级为
   `wait_until_succeeds` 轮询（与 "listening on 5432" 子测试同款防御）。
   同族加固：`nixos_core_base_nix` 的 `nix store info` 单发断言改轮询
   （nix-daemon socket 首连激活，重载 runner 上同理）。
2. **host-toplevels 腿（结构性缓存竞态）**：周日锁钉在移动分支 HEAD
   （nixos-26.05），快于渠道 Hydra 构建进度 → 源码构建桌面栈尾部
   （xdg-desktop-portal 的 meson 集成测试 2/27 失败：dynamiclauncher、
   notification/test_sound_fd）→ 连坐 system-generators 等 → 90 分钟超时
   取消（1h29m）。**裁决**：三层修复——更新流钉渠道快照 rev（上节）；
   `overlays/patches` 对 `xdg-desktop-portal` `doCheck = false`（openldap
   先例：上游易碎测试套不得扣留系统闭包构建）；host-toplevels 腿补
   vm-tests 同款「失败后逐主机重求值」诊断步。
3. **基建噪音（假失败面）**：Magic Nix Cache 代理的 GitHub Actions Cache
   418 限流（ResourceExhausted）导致 narinfo 查询禁用 60s——deep-eval 腿
   已有 infra 签名重试，本次构建腿未被其扣留（MNC 自禁后回退
   cache.nixos.org）；`use-flakehub` 默认 true 制造 79 条 FlakeHub 认证
   注解。**裁决**：全部 MNC 步显式 `use-flakehub: false`（本仓库无
   FlakeHub 注册，纯噪音面）。另修复 security 腿 extra-conf 漂移
   （补 `accept-flake-config = true`，与其余七腿对齐）。

**已立案未修（roadmap）**：runner 上 Nix 工具链身份随
`install.determinate.systems/stable` 动态解析而漂移（Determinate Nix
分叉写入的 `eval-cores` / `lazy-trees` 对来自锁定 nixpkgs 的上游 Nix
工具链是未知设置，每次调用告警）——nix-installer v3 的 tag 形态已无
`nix-*` 可钉，需要一次真机验证的钉版方案（如 `nix-package-url` 指向
releases.nixos.org 的 2.35.2 tarball）后再落地。
**→ 已于 run 38136560662 裁决中落地，见下节。**

### 事故裁决记录 — run 38136560662（2026-10-11 审计）

三个观察对象，两个真问题（均已修），一个纯基建噪音：

1. **home_core_sec `Unexpected state: starting`（真失败，测试侧，同族
   竞态第三例）**：该测试是 home plane 41 个成员中唯一对
   `systemctl is-system-running` 做 fire-once 断言的——`wait_for_unit`
   在目标单元激活即返回，而引导事务仍在收尾（失败快照：VM 到达
   multi-user.target 用时 60.98s，断言在 0.22s 后读到 `starting`）。
   兜底诊断 pass 的逐成员重求值全绿 = 评估层无罪。**裁决**：修测试
   ——断言降级为 `wait_until_succeeds` 轮询（收敛到 running/degraded，
   状态不会回退）；`meta.timeout` 60→120（慢 runner 上引导+轮询预算
   加倍）。同款防御加固 `nixos_core_base_boot`（同断言形态，防患于
   未然）。**注意失败成员的漂移模式**：`nixos_core_base_nix`（更早）
   → `nixos_core_srv_db_postgresql`（38085235502）→ `home_core_sec`
   （本轮）——每次不同的成员倒下，指向 VM 测试在重载 runner 上的
   瞬态面，而非任何单一配置错误；三例均为 fire-once 断言，全部
   收敛为轮询形态后该族竞态应告清零。
2. **Nix 工具链身份漂移（真问题，CI 侧，上轮立案项清偿）**：
   `/stable` 动态解析曾实发 Determinate Nix fork（`nix-installer`
   v3.23.1，`distribution=DeterminateNix`），其写入的
   `eval-cores=0` + `lazy-trees=true` 对锁定 nixpkgs 的上游 Nix
   是未知设置——每次调用告警。真机 A/B/C 三组验证：CLI 旗标与
   env 路线等价（`distribution=Nix` + 标准 nix.conf + 无
   determinate-nixd），但 action v13 的 `extra-args` 是死代码
   （`args.concat(extraArgs)` 返回值被丢弃）——**必须走 step env**。
   **裁决**：ci.yml ×8 + update-flake.yml ×1 全部 installer 站点
   `NIX_INSTALLER_PREFER_UPSTREAM_NIX: true` env +
   `nix-package-url` 钉 releases.nixos.org 的 2.35.2 tarball（与
   锁定 nixpkgs 同版本，身份漂移永久闭合）。
3. **Magic Nix Cache 418（假失败，基建限流）**：GitHub Actions
   Cache 代理 ResourceExhausted → MNC 自禁（"Not trying to use it
   again on this run"）→ 自动回退 cache.nixos.org，构建结果不受
   扣留。**裁决**：无需修复，计入基建噪音面（与 38085235502 的
   FlakeHub 认证注解同族——记录、不行动）。

### 自建缓存（P0）— opt-in attic 推送已落地（2026-10-11 演进）

缓存效率是对比打分中最弱的一轴（自建缓存缺位，替换命中率依赖
cache.nixos.org 与 GH Actions Cache 的二跳）。`cache-attic.yml`
落地为 **opt-in 机器契约**：`vars.ATTIC_SERVER` + `vars.ATTIC_CACHE`

+ `secret.ATTIC_TOKEN`——两个 vars 未设置时整个 workflow 每次
触发即跳过（零成本零风险），设置 vars 即部署。

+ **触发**：每周二 05:05 +08（周一 21:05 UTC，周日渠道更新 PR
  合并、周一 CI 全绿之后）+ 手动 dispatch。
+ **目标**：`nixosConfigurations` 全部 toplevel + `devShells` 矩阵
  全部闭包（host-toplevels 腿与 devshells 腿的持续物化对象）。
  枚举走 flake 面自身的 attrNames——加主机/加 shell/（未来）加
  系统维度零 CI 侧改动。
+ **工具链**：与全部九个 installer 站点同款钉版（upstream 2.35.2
  tarball + env 旗标）；MNC 开启（`use-flakehub: false`）——CI 腿
  已缓存的部分经 GH Cache 替代后直接推 attic，冷启动周付一次
  全量构建，其后为增量维护。
+ **Phase-2（记录、刻意不落地）**：缓存预热后，把该 substituter
  加入各腿 installer 的 extra-conf（需追加 `vars.ATTIC_PUBLIC_KEY`），
  让拉取侧同样吃到自建缓存——等所有者完成服务端部署后按契约
  一步开启。

### CI darwin 闭包构建腿（T8.3）— macos-latest 原机构建（2026-10-12 演进）

T8.2 落地时 darwin 闭包停在「跨系统求值步」并写明环境门控：构建需要
darwin runner 或交叉工具链。该门现已打开——GitHub 自 2025-04-10 起
`macos-latest` 指向 macOS 15 **arm64（M 系列）**镜像，公开仓库免费使用，
与主机策略声明的 `aarch64-darwin` 同形：闭包在原生平台构建，零交叉
工具链、零模拟。

+ **面**：`api.darwin-toplevels`（第六 api 面）——`inventory.darwinHosts`
  枚举驱动，成员 = `darwinConfigurations.<h>.system`（nix-darwin 的
  toplevel 本体，`darwin-rebuild` 构建的就是它）。与 host-toplevels
  完全同构的纪律：新 darwin 主机按构造入列，零 CI 侧维护。
+ **腿**：CI STAGE 6.6 `darwin-toplevels`（needs lint+deep-eval）——同工具
  同纪律：锁定 nixpkgs 解析 nix-fast-build（aarch64-darwin 成员、同 rev）、
  整面交接、`--skip-cached`；`-j` 走 `sysctl -n hw.ncpu`（macOS 无
  nproc(1)）。工具链钉版与全部 installer 站点同款 env 旗标 +
  aarch64-darwin 构建的同一 2.35.2 tarball；MNC 同款 `use-flakehub: false`。
+ **诊断 pass** 镜像 host-toplevels：nix-fast-build 非零退出时逐成员
  重求值——求值错误逐字复现即配置侧缺陷；干净扫描指向构建侧。
+ **分工**：x86_64-linux 腿的 darwin 求值步**保留**（零成本交叉系统
  检查，deep-eval 亦已强制同一 drvPath）；构建深度归 6.6 腿独有。
+ **前置核实**：nix-fast-build 的 nixpkgs 平台清单含 Darwin
  （Linux/Darwin/FreeBSD/Windows）；nix-eval-jobs 的 darwin 性能告警
  只影响 eval 密集面，本面单成员不受扰；macos-latest arm64 事实经
  GitHub runner 文档确认。
+ **验收边界**：这是**构建级**验收（closure 真实构建）；macOS
  activation 仍待真 Mac（已知边界 #8 不变）。

### devShells 腿成员枚举数据驱动（T18.1）— 最后一处硬编码成员表的消灭（2026-10-12 演进）

**发现路径**：用户提示词新增 pdshell（owner 自研的 7 阶段管道 dev shell
库——本仓 devShells 面的加载器地基）作为参考仓库 → 审视锁定关系
（flake.lock 的 pdshell rev `da51c57` 与上游 HEAD 一致，零锁更新需求）
→ 顺藤核对本仓消费面时暴露漂移：CI `evaluate-devshells` 腿的矩阵是
**写死一次就腐烂**的 9 成员列表 `[rust, python, python-machine, nix,
go, cpp, c, typescript, re]`，而活面已 **25 员**（docs-ssot 计数契约
强制）——**16 个 shell 零 CI 覆盖**：

+ `default`——14 语言 combinFrom 合并（pdshell 组合能力的最重验证对象）
+ `default.nix` 多变体：`cpython` / `godot` / `makeOs` / `rs_compiler_dev`
+ `nix/` 多变体：`nix-nonfmt` / `nix-derivation-free-security`
+ 整目录：asm / java / javascript / lisp / lua / python-renpy / zig

**同构类**：T9.3 wslview（路径依赖覆盖）与 T8.1 设计时抓到的四处计数
漂移——硬编码清单与数据驱动面之间没有同步机制，单向腐烂是结构性必然。
cache-attic.yml 的头注释甚至早已写明意图（"shells from the devShells
matrix per system attrNames. Adding a shell needs [no CI-side
change]"），但 ci.yml 的矩阵从未对齐。

**修复**：仓内既有惯例第四次复用（output-faces T11.1 / deep-eval
T15.1 / cache-attic 同款）——

+ 矩阵策略整段移除；作业内 `nix eval .#devShells.$SYS --apply
  builtins.attrNames --json` 枚举（$SYS 读自 `.#debug.test_system`，
  消灭第二处硬编码 x86_64-linux）。
+ 逐成员 `--dry-run --no-link` 循环；失败成员 `::error` 点名
  （T9.2 归因哲学）；空面守卫；显式 `set -eo pipefail`（T11.1/T15.1
  模拟器教训——不依赖 runner shell 默认值）。
+ 工具链钉版（upstream 2.35.2 tarball + env 旗标）与纯求值腿无
  magic-nix-cache 纪律原样保留（T12.1）。
+ 顺带修复：该腿头注释的 devDir 路径陈旧（home/core/dev →
  home/env/dev——树演进留下的注释级漂移）。

**验证**：YAML 结构断言十条（job 集不变 / needs 不变 / fail-gate 与
summary 接线不变 / vm-tests 平面矩阵——合法轴——不受扰）+ 全仓 34
run 块 bash -n + stub-nix 四分支运行时模拟（绿：25 员全点名计数行
正确 / 点名失败：`default` 失败时前 4 成员已点名 + stderr 流出 +
::error 命名 / 空面守卫触发 / 首成员失败快败）。

**墙钟代价**：25 次短命 dry-run 序列，flake eval-cache 首次构建后
逐成员递减；矩阵形态的 9 份 nix 安装开销 ≈ 19 runner 分钟 vs 单作业
形态 ≈ 12 分钟——覆盖从 9 → 25 员换约 3-4 分钟墙钟，runner 总分钟
反而下降。

### 事实源普查：hosts/nixos facter 迁移的机器锁（T19.1）— lib 平面 +1（2026-10-12 演进）

**背景**：T5.12 把 hosts/vm 全量迁移到声明式 facter 报告后，
hosts/nixos（真实机器）是最后一台仍在 legacy `hardware.nix` 上的主机。
迁移本身是机上门控（root 探测 + 真硬件 + 重启验收——债务 #8 环境门控
类），本仓能交付的是两件不依赖机器的事：

**`just hardware-migrate`（hardware 组，第 85 recipe）**——迁移成为
一条命令：

+ PROBE：同 `hardware-facter` 的 root 扫描（`nixpkgs#nixos-facter
  -o hosts/<h>/facter.json`）。
+ MOVE：报告表达不了的事实**原样搬入**主机入口——fileSystems、
  swapDevices、非空 `boot.kernelModules`（facter 从不生成挂载；disko
  布局是最终归宿 T5.13；microcode 已由 drive 层 intel.nix 持有、
  hostPlatform 由 report.system 派生——这些是 DERIVED，直接落）。
+ FLIP：模板 import 块（字节形校验，恰一次）换为
  `hardware.facter.reportPath = ./facter.json;`。
+ RETIRE：hardware.nix 退役——git 历史即回滚（revert 迁移提交即
  回到 legacy 接线）。

三重 fail-loudly 守卫：已迁移则绿幂等；入口被手改则拒绝并打印手动
翻转四步；hardware.nix 的每个 stanza 必须归类为 DERIVED 或 MOVED，
未知 stanza（如未来 nixos-generate-config 新增输出形态）点名拒绝。
验收地图内置 flake 语义：git add 报告先行（flakes 只看已跟踪文件）
→ census 构建 → `just nixos-test`（激活不写 boot 条目）→ 重启即真门
→ 单提交合入。

**`lib_shared_targets`（Plane 3 第 6 员，全套第 94 test）**——终态成为
机器锁：以 targets.nix mkShared 同构方式逐主机构造真实策略链
（wsl.nix 先例），读分类器自己的 caps，对 hosts/ 树断言三律——

+ **Law A**：无主机同时携带 hardware.nix 与 facter.json（双重声明
  即迁移自身的失败模式——这正是 migrate 把翻转与退役设计成同一
  命令的原因）；
+ **Law B**：裸金属 NixOS（nixos-system ∧ ¬wsl）恰一源；
+ **Law C**：宿主持有形态（wsl 类 NixOS、darwin、standalone）零源
  （无人消费的事实源文件是死数据）。

文件存在即声明——普查不看接线，这正是它的牙齿。违规时 throw 点名
主机与携带集（求值期即红，CI 的 lib 腿自动拥有该成员——平面成员
按构造入腿，零 CI 侧改动）。

**验证**（无 nix 沙箱，静态全过）：just 1.40.0 实测 `--summary`
84→85；nixfmt 1.5.0（锁定 nixpkgs 的版本号，从 flake.lock rev 直取）
两新/改文件全绿；bash -n；stub 仿真（伪 sudo + nixos-facter：挂载
UUID 逐字一致 / nvidia 指纹块完好 / kvm-intel 搬迁 / 翻转后文件
nixfmt 清洁 / 幂等重跑绿 / 无 legacy 拒绝 / 手改入口拒绝）；普查
仿真（真 hosts/ 树 + 真 caps 表：现状全绿 + 删而不翻 → Law B 点名
darwin 落杂文件 → Law C 点名 / 双源中间态 → Law A 点名 / 迁移终态
→ 全绿）。计数同步 14 处（docs-ssot 四锚点同提交流）。

### T20.1 · colmena 部署面 — 远程部署的仓库侧全量落地（2026-10-12 演进）

**发现路径**：评分短板（可运维性）+ roadmap P2 部署动词——六项演进全部入上游后，
本仓无任何远程部署叙事（nixos-rebuild 只在本机 sudo 语义下工作，第二台机器落地
即裸奔）。知识搜索三连定案：colmena 0.5.0（2026-09-22）改读 `colmenaHive` 输出
（旧 `colmena` 输出废弃）；`meta.nodeSpecialArgs` 是每节点注入 per-host policy IR
的官方机制（T5.10 单实例化跨再发射成立）；colmena 是 NixOS-only 部署面——上轮
roadmap「三形态统一 push 路径」的表述被修正为诚实的形态分治（darwin 走
darwin-rebuild，standalone HM 走 home-switch，colmena 面收敛于分类器的 nixosHosts）。

**裁决**：部署面作为 targets.nix 的第四发射面落地（编译器管道的 codegen 段加一个
目标格式），而不是 flake.nix 内的平行装配——节点复用主发射器的同一 platform 门，
meta 携带求值管道（纯 import 的 nixpkgs、per-host nodeNixpkgs、specialArgs.inputs +
nodeSpecialArgs.shared——同一个 sharedByHost thunk）。部署坐标按「数据与解释器
分离」归位为机器事实（hosts/<h>/deploy.nix，disk.nix/persist.nix 家族）+ 普查律：
colmena 永不消费的主机上出现 deploy.nix 即 throw（T19.1 Law C 的同族——说谎的
文件）。targetUser 从策略派生（ssh.nix 禁 root 禁密码，colmena 默认 root 根本
登不进来）。v1 事实只有 hosts/nixos/deploy.nix（allowLocalDeployment——本机即
部署目标）；vm/nixos-wsl 刻意无事实：不可验证的地址是说谎事实。

**修复**：flake input tarball-pinned @ v0.5.0（948491ae）——narHash 由手工 NAR
序列化器计算（Python 实现 nix archive.cc 字节格式：每字符串 8 字节对齐 / 目录
条目按名排序 / tarball 单顶层目录剥离），先用本仓 lock 里 disko + nix-darwin
两个已知 narHash 验证序列化器（双 MATCH）再算 colmena 的；follows 图——
nixpkgs/stable 跟本仓通道（makeHive 永不强制它们）、flake-utils 跟 pdshell 的
pin（colmena 输出构造即强制 eachSystem——单一实例纪律）、nix-github-actions /
flake-compat 空 follows（.lib 路径永不强制，未来强制即 loud fail）。just 三动词
（deploy 组 6→9）：deploy-list / deploy / deploy-local，CLI 钉
github:zhaofengli/colmena/v0.5.0（nixpkgs 打包版信道滞后读不了 colmenaHive）。

**验证**（无 nix 沙箱，静态全过）：flake.lock 补丁后 JSON 合法 + 锁图三断言
（follows 边解析 / 47 root inputs 全可达 / 节点形态镜像 disko 条目）；
targets.nix / flake.nix 括号平衡；ci.yml YAML 解析 + 新步 bash -n；配方计数
grep 复核 85→88；普查律仿真（真 hosts/ 树驱动：现状绿 + darwin 落 deploy.nix
→ throw 点名）。CI 等价性门控（host-toplevels 腿新步「Colmena emission
parity」）：逐 nixosHost 比对 `.#api.host-toplevels.<h>.drvPath` 与
`.#colmenaHive.toplevel.<h>.drvPath`——部署面再发射的必须恰是本腿刚构建的同一
derivation（缓存命中零重建，部署永不载运 CI 未验证的闭包）。假设论证自 colmena
0.5.0 源码：注入的四个模块是纯选项声明与空 keys 上的 mapAttrs（deployment.keys
本仓不用——secrets 走 sops-nix）、空 overlays 列表的 mkBefore 是 no-op、
name/nodes 只是附加 specialArgs；**首跑定案**（darwin 腿先例：分支 push 后的
第一次 run 是证据，mismatch 是 loud 可行动的信号而非噪音）。

**墙钟代价**：绿路径零构建（等价即缓存命中）；三台主机的额外求值 ≈ deep-eval
单主机粒度的 nix eval drvPath 序列，预计 < 3 分钟（等价性若被首跑证伪，这一步
立即指明漂移面——比在部署现场发现便宜一个数量级）。

### 事故裁决记录 — run 38171937689（2026-10-12 审计：parity 首跑 + darwin 首跑）

受测对象：main @ ca551e8（审计修复 + 七项演进全部入上游后的第一次完整 run）。
14 job：11 绿（五 VM 平面 + deep-eval + nmt + devShells + Output Faces +
Security Audit + Lint & Evaluate），3 红——两红是两条新腿的首跑定案信号，
一红是 fail-gate 的正确联动：

1. **Colmena emission parity（T20.1 门控首跑）— 捕获真实漂移**。`nixos`：
   primary `…-nixos-system-nixos-26.05.20261007.2efa67f.drv` vs colmena
   `…-nixos-system-nixos-26.05pre-git.drv`。根因（读源定案，非猜测）：
   primary 走 `nixpkgs.lib.nixosSystem`——flake 的 lib 输出经
   `lib/flake-version-info.nix` 扩展（`trivial.versionSuffix =
   ".${substring 0 8 lastModifiedDate}.${shortRev}"`，值取锁定 nixpkgs 的
   sourceInfo），toplevel 戳上 `26.05.20261007.2efa67f`；colmena 0.5 的
   hermetic 求值 `import (npkgs.path + "/nixos/lib/eval-config.nix")` 不
   转发 lib（src/nix/hive/eval.nix），raw lib 的 `trivial.versionSuffix`
   读不到源树里不存在的 `.version-suffix` 文件而回退 `"pre-git"`——同一
   模块树、同一 nixpkgs、两个 lib 身份 → 两个 derivation。T20.1 的假设
   清单（注入模块惰性）没有覆盖 flake-lib 身份这一项。**修复（T22.1）**：
   mkColmenaNode 注入 `system.nixos.versionSuffix =
   nixpkgs.lib.trivial.versionSuffix`——单源取自 flake input 自己的 lib
   （nixpkgs 改公式两边同跟踪；release 两侧本就同读 `.version` 文件，只有
   suffix 曾漂移）。静态证明：flake.lock 的 nixpkgs sourceInfo（2026-10-07 /
   2efa67f）经 overlay 公式恰好重现 primary 的观察串。parity 步提示语同步
   补 version-identity 一句。**门控按设计工作**：它抓到的不是噪音，是部署
   面再发射了 CI 未构建的闭包——正是它存在的目的。
2. **Darwin Toplevels（T8.3 首跑）— build 侧失败 + 归因盲区**。求值干净
   （腿内诊断 pass 证明：逐成员 drvPath 求值全绿），构建失败：home-manager
   闭包级联（user-environment / home-manager-fonts / hm_LibraryFonts /
   hm_fontconfigconf / home-manager-applications 全部 "1 dependency
   failed"——一个共享的包构建失败；日志可见的 cache-miss 构建是
   texliveMinimal 的 fmt 族：`texlive-2025-r78234-final-{luahbtex,luatex,
   pdftex,tex}-fmt` 与 `-env`）。环境侧证据（annotations）：GitHub cache
   服务当日故障（restore 400 ×2 / save 失败 ×2）+ macOS arm64 容量告警；
   nixpkgs-26.05-darwin 通道现指 2026-10-11 的 commit（锁 rev 10-07）——
   通道在推进，替换缺口是 darwin aarch64 的已知类（两起 90 分钟事故的
   同根因面）。**根因 derivation 无法匿名定名**：Actions 日志已登录门控
   （"Sign in to view logs"），annotations 只携带 workflow 自己的消息——
   报告者甚至贴不出根错误。**修复（T22.2）**：两条 nix-fast-build 腿
   （host-toplevels + darwin-toplevels）的失败分支追加 keep-going 归因
   ——`nix build --keep-going --no-link` 逐主机驱动构建越过首个失败，
   sed 提取 `error: build of '<drv>'` 根因行，每个真实失败的 derivation
   以 `::error` annotation 点名（store 已持有 nix-fast-build 的成功构建，
   只重建失败者：分钟级，非腿的 30 分钟墙钟）。归因哲学（T9.2）从点名
   失败成员延伸到点名失败 derivation——下一次红腿的根因对匿名读者可见。
3. **CI Summary 红**：fail-gate 正确联动（两腿红 → 汇总红）。

**顺带裁决（不动代码）**：darwin toplevel 名 `darwin-system-26.05.dirty`
的 `.dirty` = nix-darwin 以 tarball 型输入锁定（lock 无 rev →
`self.shortRev or "dirty"`）——纯命名装饰，drv 在仓内自洽；输入形态是
owner 的输入表决策，记档不动。

### 事故裁决记录 — run 38171937689 复跑（2026-10-12 审计：parity 第二裁决 + darwin 根因定名）

受测对象：main @ 91da892（T22.1/T22.2 修复自身的 run——两红皆是
前轮修复按设计交出的下一层证据，本轮双双清偿）。取证工具升级：沙箱
rootless nix（`~/nixroot/nx`，unshare + pivot_root，2.35.2）首次用于
本仓——历轮静态复核（读源论证 + 字符串仿真）从本轮起正式升级为
真实求值取证（T23 轮仅 nix-types 独立仓用过）：

1. **Parity 第二裁决（T24.1）— 名一致、哈希仍异 → derivation 递归
   diff 定案**。复跑：`nixos` primary `13q85www…` vs colmena
   `57la5407…`——**drv 名双侧完全一致**（`-nixos-system-nixos-
   26.05.20261007.2efa67f.drv`，T22.1 的 versionSuffix 修复生效），
   哈希仍异：T22.1 修复了名字，漂移转移进闭包内容。本地求值复现
   漂移对（kddnzzsk ≠ mjwh5pp4——与 CI 不同树上的同构漂移，见下
   #3 边界注），`nix derivation show` 双侧对比 + 递归下钻：**48 个
   分歧节点全部收敛到唯一叶子** `nixos-version.drv`——colmena 侧
   `@revision@` 保留运行时占位符（checkPhase 的 grep 异常集随之多
   放行 `revision@`、内嵌 json 缺 `nixpkgsRevision` 字段），primary
   侧 substitute 进完整 40-hex rev——级联链 nixos-version →
   system-path / etc → activate → toplevel。根因：
   `lib/flake-version-info.nix` 的**第二个身份字段**
   `trivial.revisionWithDefault`——flake lib 走 `self.rev or default`
   （= 锁定 rev `2efa67fd…`），plain lib 探测 store 源的 `.git` /
   `.git-revision` 双缺失（flake tarball 源）→ null。**两个字段、
   两次漂移、两裁决**：versionSuffix 漂移改 drv 名（首跑可见），
   revision 漂移改闭包内容（复跑可见）。修复：mkColmenaNode 注入
   `system.nixos.revision = nixpkgs.lib.trivial.revisionWithDefault null`
   （T22.1 同族第二行，单源 flake input 自己的 lib）。**真实求值
   验证**：修复后 `.#colmenaHive.toplevel.nixos.drvPath` ==
   `.#api.host-toplevels.nixos.drvPath`（等价性为不变量）。parity
   门提示语同步扩为两字段身份说明——第三类漂移出现时 diff 双 drv
   即秒诊。
2. **Darwin 根因定名（T24.2）— keep-going 归因首战告捷 → 位对位
   复现 → overlay 实例局部性清偿**。复跑红腿：T22.2 的 `--keep-going`
   归因步让根因以 `::error` annotation 可见——`cutter-2.5.0.drv`
   要求 `x86_64-linux` 却在 `aarch64-darwin` 构建闭包（平台不匹配，
   构建侧即刻失败）。本地 `nix derivation show --recursive` 复现：
   darwin 闭包内 cutter drv 与 CI 失败 drv **哈希一字不差**
   （`7mjhjj4k…`），`system = x86_64-linux`，postPatch 确认为
   overlays 的 `cutter_patched`。根因链（读源定案）：shared.nix 的
   `nixpkgs.overlays` 引用 `shared.self.overlays`——**flake 级
   overlays 输出，以 targets.base（基础工作站 IR）单次实例化**——
   patches 里 `cutter_patched = shared.upkgs.cutter…` 的 upkgs 因此
   恒为基础主机的 x86_64-linux 实例，无论 overlay 被应用到哪个
   主机的 pkgs/upkgs。**掩盖机制**：同类的跨界成员（home/env/base
   的 gcc/gdb/rustc 等）全部可从 cache.nixos.org 替换（替换不要求
   平台匹配）——跨界静默；cutter_patched 的 postPatch 造出独有
   哈希，永不在缓存 → 必须本地构建 → macOS runner 平台不匹配
   即刻爆炸。修复：`cutter_patched = prev.cutter…`——实例局部
   （overlay 契约本身：改谁补谁，`prev` 即所应用实例自己的不动点）
   ；文件签名去 `shared` 参数（跨界需求在类型上不可表达）。**linux
   侧字节不变证明**：base 主机上 `prev.cutter` == 原
   `shared.upkgs.cutter`，`upkgs.cutter_patched` 修复前后同为
   `7mjhjj…`。**新测试 `lib_shared_overlays`（第 96 号）**：canary
   替换实例法——patches 应用到标记 stub 实例（meta.description
   穿透 overrideAttrs 存活），每个被补成员必须携带标记，从任何
   外部句柄取包即失标即红；变异检查实测：回退 bug 形态 → census
   点名 `cutter_patched`。**全闭包审计**：修复后 darwin 闭包
   9,464 drv 的 system 分布 = aarch64-darwin 9,462 + builtin 2——
   **跨界类清零**；闭包同时 13,317 → 9,464（x86_64-linux 子树
   整体退场——那 3,853 个 drv 本就不该在 macOS 闭包里）。
3. **边界注（已知边界 #10 的现场演示）**：CI 的 primary
   `13q85www` vs 本地 `kddnzzsk`——不同树（91da892 vs 复现树）上
   同一 emission 的哈希不同：toplevel 经 registry self 通道追踪树
   内容（#10 记录在案），双侧同移，**等价性（primary == colmena）
   才是可断言的不变量**；而 `7mjhjj…`（cutter_patched）这类不触
   self 的 drv 与树无关——CI 与本地一字不差，恰是两侧闭包内容
   同源的最强交叉证据。

### 首绿裁决记录 — run 38192402014 + 38234435660（2026-10-12：双红清偿验收 + 首次全绿）

受测对象：main @ c44cde9（T24 双根因清偿的采纳形态）→ run
38192402014；main @ 20a59b3（T25 lock bump + 第 97 号 version 契约
断言的采纳形态）→ run 38234435660。**两 run 全 14 作业全绿**——
38171937689 的双红（parity + darwin）至此完成完整清偿弧，且新状态
稳定复绿：

1. **run 38192402014（c44cde9）— 首次全绿，冷构建**。parity 腿
   （output-faces 内的等价门控）绿：两字段身份注入后 primary ==
   colmena 在 CI 真实成立——parity 门的生命周期闭环（**设计捕获 →
   两跑裁决 → 修复 → 绿**），门的全部四个阶段都在生产 run 里走过。
   darwin 腿绿：**darwin 闭包首次在 macOS runner 原机构建成功**——
   含 cutter_patched（postPatch 独有哈希、永不在缓存的那类）的
   aarch64-darwin 实例本地构建；闭包 9,464 drv 的大头经
   cache.nixos.org 替代（同 rev），纯本仓派生物原机产出。计时
   证据（缓存轴的活体基线）：整 run 01:34:20Z → 02:41:42Z
   （约 67 分钟），两条闭包腿 ~1h2m / ~1h7m——T24.2 修复把 darwin
   闭包从「必炸」变「可建」，成本即此；run 级空转（纯替换 + 零
   本仓重建）的对照见下一条。
2. **run 38234435660（20a59b3）— 复绿，热跑**。T25 是求值期机器
   （nix-types 不进闭包，darwin toplevel 与 T24 轮同哈希
   v66nskmz），两 commit 间闭包零漂移 → MNC 跨 run 缓存全命中：
   最长腿 3m9s——与上一 run 的 ~1h 腿对照，**缓存轴的现状画像**
   （零漂移周快、漂移周冷构建一小时）：attic phase-2 的增益空间
   正是后者（owner 侧 vars 待设，契约已备）。
3. **第 97 号测试的 CI 首验**：38234435660 是 lock bump + version
   契约断言入 CI 的首个 run——lib 平面 97 tests 在 CI 求值绿（本地
   T25 轮已绿 + 变异检查红），version 契约（rev 答 where、version
   答 what）首次在 CI 环境成立。

### 缓存轴接线裁决 — Cachix 公开层（2026-10-13：owner 侧动词落地后的仓库侧接线）

背景：评分最弱轴（缓存 6.5/10）的根治路径经对比评审定为「Cachix
免费层先落地 → attic/harmonia 规模化」。run 38385434464（e5dcf1f
重触发，owner 手动）再次实证病灶：13/14 作业绿，唯一红是 Host
Toplevels 自限时 90 分钟取消——冷缓存闭包构建超预算的恶性循环
（一次超时 → 闭包产物不入任何缓存 → 后续 run 依旧冷）。owner 侧
动词已落地：公开缓存 redskaber-nix-config（ZSTD、priority 41）
创建在线，但仓库侧零接线、缓存为空（toplevel narinfo 404 实测）。
本 commit 补上接线——两半，均为 CI 层关注点（分发逻辑归位分发层
——对 flake 仓库而言就是 runner 的 nix.conf，绝不进 Nix 配置）：

1. **PULL（无条件）**：11 个 Install Nix 腿（ci.yml ×9、
   update-flake.yml、cache-attic.yml）的 extra-conf 统一加
   substituters + trusted-public-keys。公开缓存零鉴权（narinfo
   404 即无操作）；priority 41 保持在 cache.nixos.org（40）之后，
   5 GB 免费层只服务 Hydra 追不上的缺口——锁钉在 nixos-26.05
   移动分支 HEAD、快于 Hydra 渠道进度，正是 38085235502 与
   38385434464 两次 90 分钟源码构建尾部的根因。
2. **PUSH（opt-in）**：host-toplevels 腿构建步之后加推缓存步，
   `if: always()` + 脚本内判空（round-17 修正：初版
   `if: always() && secrets.CACHIX_AUTH_TOKEN != ''` 被 GitHub 校验器
   拒绝——secrets 上下文对 if: 表达式不可见，可用上下文仅
   env/github/inputs/job/matrix/needs/runner/steps/strategy/vars；
   守卫移入脚本对 env 映射 token 判空、未设即 exit 0 INERT）。
   工具走锁定 nixpkgs 的 `nix run $PKGS#cachix`（cachix 1.11.1，与
   nix-fast-build 同纪律）；路径经 outPath 纯求值 + store 存在性
   过滤（构建中失败仍缓存已建前缀，供重试替代；超时类杀整个
   job 无法推——这正是下面的 bootstrap 提时要解决的）。
3. **BOOTSTRAP**：host-toplevels timeout 90 → 150：首个锁后冷
   run 需要越过旧上限一次，才能把「缺口代」推入缓存；缓存持有
   完整一代后 substituter 把重建塌缩成替代，可回访收紧。
4. **配额诚实账**：闭包约 1–1.5 GB ZSTD/代，锁周更 → 5 GB 免费
   层约 3–4 代满；出路按序：面板清老代 → 付费层 → harmonia
   （复用现有 kilig-nixos 常开主机，零边际成本——规模化终态；
   cache-attic.yml 的 attic 设计保留为自建选项，其头部 round-16
   注记同步）。MNC 保留（承载 run 内求值腿），其 418 限流史
   （T12.1）与 10 GB/7 天逐出不变——本缓存是其结构上做不到的
   持久层。darwin 腿与 vm 腿的推缓存为 phase-2（绿且快，配额
   优先给红腿）。

### 守卫位置修正 — secrets 对 if: 不可见（2026-10-13：第 17 轮，交付缺陷的诚实账）

owner 消费门户交付物（接线 diff）后落 main 为 ccf9edb，GitHub
校验器立即拒绝：

```
Invalid workflow file: .github/workflows/ci.yml#L1
(Line: 1120, Col: 13): Unrecognized named-value: 'secrets'.
Located at position 13 within expression:
always() && secrets.CACHIX_AUTH_TOKEN != ''
```

根因：GitHub Actions 表达式的**上下文可用性表**把 `secrets` 排除在
`if:` 位置之外（step 级 if: 可见上下文仅 env/github/inputs/job/
matrix/needs/runner/steps/strategy/vars）；`secrets` 的合法位置是
`env:`/`with:`/`run` 值位。owner 自己的 cache-attic.yml 从未违例
——其 job 级门用 `vars.ATTIC_SERVER`（vars 对 if: 可见），token 只
进 `env:` 值位；第 16 轮宣称的「cache-attic.yml 同款纪律」在守卫
位置上是错误类比。初版守卫被写成 `if: always() && secrets.X != ''`
（校验时即拒绝、零 run 可跑——main 的 CI 因此全瘫，直至本修正）。

修复（同 commit）：

1. **守卫移位**：`if: always()` 保留（构建失败仍推已建前缀的语义
   不变），判空进脚本——`env:` 映射 token（未设 secret 求值为空
   串），脚本首段 `[ -z "${CACHIX_AUTH_TOKEN:-}" ] && exit 0`
   （`::notice` 注明 INERT opt-in）。secrets 只在合法位置出现。
2. **文档三处**：ci.yml 头部 PUSH 注记 + push 步注释 + 本条目。

「缺陷变门」（T26 卫生门 / T29 上游守卫 / T32 语法门的第四案）：
actionlint 1.7.12（锁定 nixpkgs，Hydra 全命中零构建）在本地**逐字
复现**该校验器拒绝（`ci.yml:1120:25: context "secrets" is not
allowed here. available contexts are …`）——即该错误类存在本地
可跑的最廉价门。提案：pre-commit 增加 actionlint hook（lint 腿
pre-commit 现仅 nixfmt/statix/deadnix——YAML/表达式层零覆盖，正是
本缺陷穿过三重本地验证直达 GitHub 的原因）。修复树已用 actionlint
复扫：secrets 类错误清零；余 139 行均 shellcheck 弱风格提示
（SC2086 等，owner 既有脚本同在，非 blocker、不属本轮范围）。
