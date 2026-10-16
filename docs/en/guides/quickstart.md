# Quick Start — The Full Guided Path from Zero to Deployment (just-driven)

> English mirror of [docs/guides/quickstart.md](../../guides/quickstart.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> This document is the full version of the README's "Quick Start" section
> (moved out of the README verbatim during the T13.1 layered refactoring).
> Six phases, followable from bare metal; the README keeps a quick overview
> of the first-deployment main path.

> Six phases, every step a just verb or an explicit nix command; whenever you
> are unsure at any step, go back to the corresponding guide (`just
> secrets-guide` / `just --list`). This section is the complete path "starting
> from zero" — followable from bare metal; machines that already exist can
> enter at a middle phase.

### Phase 0 — Bare metal → Nix + just ready

**NixOS** (Nix built in; the LiveISO ships it too): skip to Phase 1.

**Non-NixOS Linux / macOS / WSL2** (home-manager layer only):

```bash
# 安装 Nix（Determinate Systems 安装器，带 flakes 支持开箱即用）
curl -L https://install.determinate.systems/nix | sh -s -- install

# 启用 flakes（官方安装器或已有安装需要手动开启）
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes pipe-operators" >> ~/.config/nix/nix.conf
```

**Making just available** (the entry to every operation plane of this
repository; not installed globally — entered ephemerally):

```bash
nix shell nixpkgs#just nixpkgs#git      # 或: nix-shell -p just git
```

> From here on, all commands are executed at the repository root (that is
> where `just` anchors its ROOT).

### Phase 1 — Clone + the policy and key baseline

> **Note:** After the first NixOS build, directories under non-`/` mount
> points come under NixOS management — put the configuration in a suitable
> path. If the first build is not done from outside the system's own
> directories, the remaining ~/* will be wiped out (because the user
> identity has not been created yet, among other reasons). (nixos itself)
>
> Subsequent builds do not have this problem

```bash
git clone https://github.com/Redskaber/nix-config /etc/nix-config
cd /etc/nix-config
```

**Personal machine** (user key, single-key baseline):

```bash
just init <username>
#   = shared-generate（策略真值 shared.nix）
#   + hardware-generate（hosts/<hostname>/hardware.nix 硬件探测）
#   + secrets-init（目录 + user age 密钥 + .sops.yaml 基线）
```

**Server machine** (user + host dual-key direct bootstrap — two steps
replacing three):

```bash
just key-new-host <alias>                # ① 生成 host keypair（仓外交付副本，chmod 400）
just init <username> <alias> <age1…>     # ② 直达 USER+HOST（srv 域双收件人）
# ③ 交付副本 → 目标机 /var/lib/sops-nix/key.txt（chmod 400）后 shred
```

> Already bootstrapped as a personal machine and want to bring a host key in
> incrementally? Use `just key-add-host` + `secrets-sync` (see the four-step
> flow in `just secrets-guide`).

### Phase 2 — secrets ready

```bash
just secrets-plan-create                # 可选：生成明文模板参考（填写前对照）

nix shell nixpkgs#mkpasswd --command just secret-set-all
# 交互式逐项录入（输入即加密，明文不落盘）；或按需单独：
#   just secret-set userpwd             # 用户系统密码（mkpasswd sha-512）
#   just secret-set nix                 # GitHub access token
#   just secret-set mongodb             # ...

just secrets-verify                     # 收件人一致性审计（期望全绿，红则按提示修）
just secrets-status                     # 三层状态总览（key / rule / blob + 本机 identity）
```

> **Personal machine that also runs srv services** (dev-on-demand db
> profile)? After bootstrapping with the direct dual key in Phase 1, land
> the host identity on this machine as well: `just key-install-host
> <alias>` — the single user key of the baseline state already suffices,
> but both the hardened srv policy (host-only) and this machine's independent
> recovery path require it to be in place (see rotation.md §2b "own host =
> srv host" for details).

### Phase 3 — First deployment

```bash
just hosts-list                  # 确认主机键（hosts/ 目录数据驱动）
```

**A. Brand-new NixOS machine (installed from LiveISO)**:

```bash
# 分区 + 挂载后（/ 与 /boot），在目标环境生成硬件配置并安装：
sudo nixos-install --flake /etc/nix-config#<host>
```

**B. Existing NixOS system (take over / switch to this configuration)**:

```bash
just nixos-switch <host>         # = sudo nixos-rebuild switch --flake .#<host>
```

**C. Non-NixOS platforms (home-manager layer only)**:

```bash
just home-switch <host>          # → <username>@<host>（如 just home-switch wsl）
# macOS: darwin-rebuild switch --flake .#<host>
```

### Phase 4 — Verification and rollback

```bash
just secrets-status              # secrets 三层健康
nixos-rebuild list-generations   # 世代清单（每次 switch 一代）
sudo nixos-rebuild rollback      # 一键回上一代
just nixos-test <host>           # 试验性切换（不写 boot 条目，重启即弃）
just nixos-boot <host>           # 只设下一代引导不激活（T10.2——远程/回滚风味更安全的部署面）
```

### Phase 5 — day-2 quick reference (after going live)

```bash
# 例行更新（sops-nix 锁版本，防意外破坏解密链）
just flake-update-not-sops && just nixos-switch <host>

# secrets 生命周期（地图: just secrets-guide / 文档: docs/secrets/rotation.md）
just secrets-verify              # CI 同款审计
just key-rotate-user <age1…>     # user key 轮换（三步引导）
just key-rotate-host <age1…>     # host key 轮换（加新→重加密→撤旧）

# 新机器接入 = mkdir hosts/<name> + 两个文件（零 flake 改动）
# 新 secret 声明 = 三层（shared.nix.tmpl / 模板 YAML / 4 行 recipe，见扩展指南）
```

### Development environments

```bash
# 一次性进入（不保存 profile）
nix develop .#rust
nix develop .#python
nix develop .#python-machine

# 持久化 profile（离线可用，下次快速进入）
just devenv-create rust
just devenv-create-from python machine

# 进入已有 profile
just devenv-use rust
just devenv-use-from python machine

# 通过 direnv 自动激活（推荐工作流）
echo "use flake github:Redskaber/nix-config#python-machine" > .envrc
direnv allow
```

---
