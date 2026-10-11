# CI/CD 深度手册 — 缘起、本地预检与部署流

> 本文收纳 README「CI/CD 完整执行流」节的深度部分（T13.1 分层重构时迁出）：
> 为什么需要 CI/CD、本地预检清单、部署工作流、世代管理与回滚、自动化更新。
> 流水线全景图与缓存策略见 [README](../../README.md#cicd-完整执行流)。

### 为什么 Nix 配置需要 CI/CD

每次变更 nix-config 都等价于声明一个新的系统状态。CI 的核心价值：

1. **求值检查** — 捕获 Nix 语法/类型错误（早于 nixos-rebuild 失败）
2. **深层求值** — 面分片强制（T15.1）：api 信封 + 逐主机 toplevel drvPath + 杂项 checks + 完备性对账（全部 96 checks 必须被平面或杂项清单拥有；单进程 `nix flake check` 因内存累积地板已退役）
3. **Secret 完整性 + 供应链** — 验证加密文件结构正确，`secrets/plan/` 未被提交；
   全部 GitHub Actions 引用钉版为 40-hex commit SHA（T16.1 机器契约：
   未钉版引用在 Security Audit 腿 fail-fast 红灯，上游 tag 被篡改不影响本流水线）
4. **测试覆盖** — 94 tests 覆盖 nixos/home/lib/integration/nmt 平面
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

- **触发**：每周二 05:05 +08（周一 21:05 UTC，周日渠道更新 PR
  合并、周一 CI 全绿之后）+ 手动 dispatch。
- **目标**：`nixosConfigurations` 全部 toplevel + `devShells` 矩阵
  全部闭包（host-toplevels 腿与 devshells 腿的持续物化对象）。
  枚举走 flake 面自身的 attrNames——加主机/加 shell/（未来）加
  系统维度零 CI 侧改动。
- **工具链**：与全部九个 installer 站点同款钉版（upstream 2.35.2
  tarball + env 旗标）；MNC 开启（`use-flakehub: false`）——CI 腿
  已缓存的部分经 GH Cache 替代后直接推 attic，冷启动周付一次
  全量构建，其后为增量维护。
- **Phase-2（记录、刻意不落地）**：缓存预热后，把该 substituter
  加入各腿 installer 的 extra-conf（需追加 `vars.ATTIC_PUBLIC_KEY`），
  让拉取侧同样吃到自建缓存——等所有者完成服务端部署后按契约
  一步开启。

### CI darwin 闭包构建腿（T8.3）— macos-latest 原机构建（2026-10-12 演进）

T8.2 落地时 darwin 闭包停在「跨系统求值步」并写明环境门控：构建需要
darwin runner 或交叉工具链。该门现已打开——GitHub 自 2025-04-10 起
`macos-latest` 指向 macOS 15 **arm64（M 系列）**镜像，公开仓库免费使用，
与主机策略声明的 `aarch64-darwin` 同形：闭包在原生平台构建，零交叉
工具链、零模拟。

- **面**：`api.darwin-toplevels`（第六 api 面）——`inventory.darwinHosts`
  枚举驱动，成员 = `darwinConfigurations.<h>.system`（nix-darwin 的
  toplevel 本体，`darwin-rebuild` 构建的就是它）。与 host-toplevels
  完全同构的纪律：新 darwin 主机按构造入列，零 CI 侧维护。
- **腿**：CI STAGE 6.6 `darwin-toplevels`（needs lint+deep-eval）——同工具
  同纪律：锁定 nixpkgs 解析 nix-fast-build（aarch64-darwin 成员、同 rev）、
  整面交接、`--skip-cached`；`-j` 走 `sysctl -n hw.ncpu`（macOS 无
  nproc(1)）。工具链钉版与全部 installer 站点同款 env 旗标 +
  aarch64-darwin 构建的同一 2.35.2 tarball；MNC 同款 `use-flakehub: false`。
- **诊断 pass** 镜像 host-toplevels：nix-fast-build 非零退出时逐成员
  重求值——求值错误逐字复现即配置侧缺陷；干净扫描指向构建侧。
- **分工**：x86_64-linux 腿的 darwin 求值步**保留**（零成本交叉系统
  检查，deep-eval 亦已强制同一 drvPath）；构建深度归 6.6 腿独有。
- **前置核实**：nix-fast-build 的 nixpkgs 平台清单含 Darwin
  （Linux/Darwin/FreeBSD/Windows）；nix-eval-jobs 的 darwin 性能告警
  只影响 eval 密集面，本面单成员不受扰；macos-latest arm64 事实经
  GitHub runner 文档确认。
- **验收边界**：这是**构建级**验收（closure 真实构建）；macOS
  activation 仍待真 Mac（已知边界 #8 不变）。

### devShells 腿成员枚举数据驱动（T18.1）— 最后一处硬编码成员表的消灭（2026-10-12 演进）

**发现路径**：用户提示词新增 pdshell（owner 自研的 7 阶段管道 dev shell
库——本仓 devShells 面的加载器地基）作为参考仓库 → 审视锁定关系
（flake.lock 的 pdshell rev `da51c57` 与上游 HEAD 一致，零锁更新需求）
→ 顺藤核对本仓消费面时暴露漂移：CI `evaluate-devshells` 腿的矩阵是
**写死一次就腐烂**的 9 成员列表 `[rust, python, python-machine, nix,
go, cpp, c, typescript, re]`，而活面已 **25 员**（docs-ssot 计数契约
强制）——**16 个 shell 零 CI 覆盖**：

- `default`——14 语言 combinFrom 合并（pdshell 组合能力的最重验证对象）
- `default.nix` 多变体：`cpython` / `godot` / `makeOs` / `rs_compiler_dev`
- `nix/` 多变体：`nix-nonfmt` / `nix-derivation-free-security`
- 整目录：asm / java / javascript / lisp / lua / python-renpy / zig

**同构类**：T9.3 wslview（路径依赖覆盖）与 T8.1 设计时抓到的四处计数
漂移——硬编码清单与数据驱动面之间没有同步机制，单向腐烂是结构性必然。
cache-attic.yml 的头注释甚至早已写明意图（"shells from the devShells
matrix per system attrNames. Adding a shell needs [no CI-side
change]"），但 ci.yml 的矩阵从未对齐。

**修复**：仓内既有惯例第四次复用（output-faces T11.1 / deep-eval
T15.1 / cache-attic 同款）——

- 矩阵策略整段移除；作业内 `nix eval .#devShells.$SYS --apply
  builtins.attrNames --json` 枚举（$SYS 读自 `.#debug.test_system`，
  消灭第二处硬编码 x86_64-linux）。
- 逐成员 `--dry-run --no-link` 循环；失败成员 `::error` 点名
  （T9.2 归因哲学）；空面守卫；显式 `set -eo pipefail`（T11.1/T15.1
  模拟器教训——不依赖 runner shell 默认值）。
- 工具链钉版（upstream 2.35.2 tarball + env 旗标）与纯求值腿无
  magic-nix-cache 纪律原样保留（T12.1）。
- 顺带修复：该腿头注释的 devDir 路径陈旧（home/core/dev →
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

- PROBE：同 `hardware-facter` 的 root 扫描（`nixpkgs#nixos-facter
  -o hosts/<h>/facter.json`）。
- MOVE：报告表达不了的事实**原样搬入**主机入口——fileSystems、
  swapDevices、非空 `boot.kernelModules`（facter 从不生成挂载；disko
  布局是最终归宿 T5.13；microcode 已由 drive 层 intel.nix 持有、
  hostPlatform 由 report.system 派生——这些是 DERIVED，直接落）。
- FLIP：模板 import 块（字节形校验，恰一次）换为
  `hardware.facter.reportPath = ./facter.json;`。
- RETIRE：hardware.nix 退役——git 历史即回滚（revert 迁移提交即
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

- **Law A**：无主机同时携带 hardware.nix 与 facter.json（双重声明
  即迁移自身的失败模式——这正是 migrate 把翻转与退役设计成同一
  命令的原因）；
- **Law B**：裸金属 NixOS（nixos-system ∧ ¬wsl）恰一源；
- **Law C**：宿主持有形态（wsl 类 NixOS、darwin、standalone）零源
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
