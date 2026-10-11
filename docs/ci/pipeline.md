# CI/CD 深度手册 — 缘起、本地预检与部署流

> 本文收纳 README「CI/CD 完整执行流」节的深度部分（T13.1 分层重构时迁出）：
> 为什么需要 CI/CD、本地预检清单、部署工作流、世代管理与回滚、自动化更新。
> 流水线全景图与缓存策略见 [README](../../README.md#cicd-完整执行流)。

### 为什么 Nix 配置需要 CI/CD

每次变更 nix-config 都等价于声明一个新的系统状态。CI 的核心价值：

1. **求值检查** — 捕获 Nix 语法/类型错误（早于 nixos-rebuild 失败）
2. **深层求值** — 面分片强制（T15.1）：api 信封 + 逐主机 toplevel drvPath + 杂项 checks + 完备性对账（全部 95 checks 必须被平面或杂项清单拥有；单进程 `nix flake check` 因内存累积地板已退役）
3. **Secret 完整性 + 供应链** — 验证加密文件结构正确，`secrets/plan/` 未被提交；
   全部 GitHub Actions 引用钉版为 40-hex commit SHA（T16.1 机器契约：
   未钉版引用在 Security Audit 腿 fail-fast 红灯，上游 tag 被篡改不影响本流水线）
4. **测试覆盖** — 93 tests 覆盖 nixos/home/lib/integration/nmt 平面
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

# 4. devShell dry-run
nix build .#devShells.x86_64-linux.rust --dry-run --no-link

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
