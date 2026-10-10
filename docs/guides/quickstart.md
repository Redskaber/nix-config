# 快速开始 — 从 0 到部署的全流程引导（just 驱动）

> 本文是 README「快速开始」节的完整版（T13.1 分层重构时从 README 原样迁出）。
> 六个 Phase，裸机可循；README 保留首部署主路径速览。

> 六个 Phase，每步都是 just 动词或显式 nix 命令；任何一步不确定时回到
> 对应 guide（`just secrets-guide` / `just --list`）。本节就是"从 0 开始"
> 的完整路径——裸机可循，已有机器可从中间 Phase 进入。

### Phase 0 — 裸机 → Nix + just 就绪

**NixOS**（已内置 Nix；LiveISO 同样自带）：跳到 Phase 1。

**非 NixOS Linux / macOS / WSL2**（只用 home-manager 层）：

```bash
# 安装 Nix（Determinate Systems 安装器，带 flakes 支持开箱即用）
curl -L https://install.determinate.systems/nix | sh -s -- install

# 启用 flakes（官方安装器或已有安装需要手动开启）
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes pipe-operators" >> ~/.config/nix/nix.conf
```

**just 的可用性**（本仓库所有操作面的入口；不全局安装，一次性进入）：

```bash
nix shell nixpkgs#just nixpkgs#git      # 或: nix-shell -p just git
```

> 从这里开始，所有命令都在仓库根目录执行（`just` 的 ROOT 锚定）。

### Phase 1 — 克隆 + 策略与密钥基线

> **注意：** NixOS 首次 build 后，非 `/` 挂载点下的目录会被 NixOS 管理，请将配置放在合适路径。
> 首次 build 如果不是在系统别目录下，由于用户身份未创建等原因，会将其余的 ～/\* 清除。(nixos 本身)
>
> 后续再次构建不会有此问题

```bash
git clone https://github.com/Redskaber/nix-config /etc/nix-config
cd /etc/nix-config
```

**个人机**（user key 单 key 基线）：

```bash
just init <username>
#   = shared-generate（策略真值 shared.nix）
#   + hardware-generate（hosts/<hostname>/hardware.nix 硬件探测）
#   + secrets-init（目录 + user age 密钥 + .sops.yaml 基线）
```

**服务器机**（user + host 双 key 直达引导，两步取代三步）：

```bash
just key-new-host <alias>                # ① 生成 host keypair（仓外交付副本，chmod 400）
just init <username> <alias> <age1…>     # ② 直达 USER+HOST（srv 域双收件人）
# ③ 交付副本 → 目标机 /var/lib/sops-nix/key.txt（chmod 400）后 shred
```

> 已按个人机引导过、想增量接入 host key？走 `just key-add-host` +
> `secrets-sync`（见 `just secrets-guide` 的四步流）。

### Phase 2 — secrets 就绪

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

> **个人机同时跑 srv 服务**（dev-on-demand db profile）？Phase 1 用直达双 key
> 引导后，把 host identity 也落位本机：`just key-install-host <alias>`
> ——基线态单把 user key 已够用，但硬化 srv 策略（host-only）与本机独立
> 恢复路径都要求它就位（详见 rotation.md §2b「own host = srv host」）。

### Phase 3 — 首次部署

```bash
just hosts-list                  # 确认主机键（hosts/ 目录数据驱动）
```

**A. 全新 NixOS 机（从 LiveISO 安装）**：

```bash
# 分区 + 挂载后（/ 与 /boot），在目标环境生成硬件配置并安装：
sudo nixos-install --flake /etc/nix-config#<host>
```

**B. 已有 NixOS 系统（接管/切换到本配置）**：

```bash
just nixos-switch <host>         # = sudo nixos-rebuild switch --flake .#<host>
```

**C. 非 NixOS 平台（仅 home-manager 层）**：

```bash
just home-switch <host>          # → <username>@<host>（如 just home-switch wsl）
# macOS: darwin-rebuild switch --flake .#<host>
```

### Phase 4 — 验证与回滚

```bash
just secrets-status              # secrets 三层健康
nixos-rebuild list-generations   # 世代清单（每次 switch 一代）
sudo nixos-rebuild rollback      # 一键回上一代
just nixos-test <host>           # 试验性切换（不写 boot 条目，重启即弃）
just nixos-boot <host>           # 只设下一代引导不激活（T10.2——远程/回滚风味更安全的部署面）
```

### Phase 5 — day-2 速查（上线之后）

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

### 开发环境

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
