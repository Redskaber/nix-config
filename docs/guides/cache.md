# 缓存指南 — 本地拉取与推送（redskaber-nix-config 公开层）

> 本文覆盖 CI 之外的本地工作流：**拉取**（任何机器，零鉴权）与**推送**
> （owner 侧动词，需 auth token）。CI 侧的接线与裁决见
> [docs/ci/pipeline.md](../ci/pipeline.md) 第 16/17/18 轮条目——两份文档
> 同源不同受众：pipeline.md 回答「CI 为什么这样设计」，本文回答
> 「我的机器怎么用这个缓存」。

## 缓存是什么（一段话）

公开 Cachix 缓存 `redskaber-nix-config`（ZSTD、priority 41、公钥
`redskaber-nix-config.cachix.org-1:ziIAJzLVe11AexFTrAY3IZVTZQOWUa5vmFB3eeaW8zw=`）。
它只服务一件事：**锁钉在 nixos-26.05 移动分支 HEAD 造成的 Hydra 缺口**——
锁快于渠道二进制进度，冷 run 的闭包构建尾部（历史实测 1h+）在本缓存
有内容后塌缩为替代下载。priority 41 保持在 cache.nixos.org（40）之后：
两边都有的路径永远走官方——免费层 5GB 只花在官方追不上的缺口上。

## 拉取（任何机器，无需 token）

两种等价形式，落点都是机器的 nix.conf：

**形式一：cachix CLI 一条命令**（常驻机器推荐）

```bash
# CLI 从锁定 nixpkgs 取（与 CI 同源同纪律，本机无需安装）
nix run nixpkgs#cachix -- use redskaber-nix-config
```

`cachix use` 按机器形态自动落点（`-m` 可显式指定）：
`nixos`（生成 /etc/nixos 配置片段）/ `root-nixconf`（写 /etc/nix/nix.conf）/
`user-nixconf`（写 ~/.config/nix/nix.conf，单用户安装形态）。

**形式二：手动 nix.conf**（受控环境 / 沙箱的显式形式——与 CI 腿同款）

```conf
# ~/.config/nix/nix.conf（或 /etc/nix/nix.conf，按安装形态）
substituters = https://redskaber-nix-config.cachix.org https://cache.nixos.org
trusted-public-keys = redskaber-nix-config.cachix.org-1:ziIAJzLVe11AexFTrAY3IZVTZQOWUa5vmFB3eeaW8zw= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
```

**验证拉取配置生效**：

```bash
nix store ping --store https://redskaber-nix-config.cachix.org
# 缓存为空时 narinfo 404 是无害空操作，nix 自然回退 cache.nixos.org
```

**形式三：flake 自带 nixConfig**（本仓 checkout 的消费者，零配置）

flake.nix 声明 `extra-substituters` + `extra-trusted-public-keys`——任何从
本仓 build/eval 的机器自动获得该缓存（首次会提示 accept-flake-config，
或机器信任配置跳过）。`extra-` 语义：追加到机器默认 substituters 之后
（不在前面抢占），只补官方没有的路径——与本缓存 priority 41 的定位一致。

```bash
nix build .#checks.x86_64-linux.module-reachability-check --no-link
# 首次运行问 "Extra substituters... accept?" → y（或 nix config set
# accept-flake-config true 预授权）
```

拉取**不需要** auth token——公开缓存零鉴权。这也是 CI 侧 PULL
无条件 ×11 腿成立的原因（见 pipeline.md 第 16 轮）。

**darwin 主机运行时注意**：darwin-rebuild 用的是 /etc/nix/nix.conf，
flake nixConfig 不落盘——形式一/二任选其一落到机器；平台侧 darwin
nix settings 模块属 roadmap 项（涉真实主机运行时语义，留 owner 决策）。

## 推送（owner 侧动词，需 token）

**首选形态：仓内动词一条龙**（token 从秘密系统解析，无需手设环境）：

```bash
just cachix-status                 # 推送前看一眼：可达性 / 受信 / 两半场状态
just cachix-token                  # 一次性：注册 cachix-token 秘密 + 引导录入值
just cachix-push /nix/store/…-nixos-system-…
# 或构建即推：
nix build .#checks.x86_64-linux.module-reachability-check --no-link && \
  just cachix-push $(nix build --print-out-paths .#checks.x86_64-linux.module-reachability-check)
```

动词的解析链：token 取 `CACHIX_AUTH_TOKEN` env → 秘密系统
（`just cachix-token` 落地的 blob，**叶提取裸值**）；cachix 二进制取
`$CACHIX_BIN` → PATH → `nix shell nixpkgs#cachix`。多路径一次推全，
每路径推**完整闭包**。

**底层 CLI**（动词包装的就是它——理解语义或脱离本仓时用）：

```bash
# token 一次性落地（cachix.org → cache 设置页创建，写入本机）
nix run nixpkgs#cachix -- authtoken <CACHIX_AUTH_TOKEN>
# 落 ~/.config/cachix/cachix.dhall；或每次经 CACHIX_AUTH_TOKEN 环境变量传入

# 显式路径推送
nix run nixpkgs#cachix -- push redskaber-nix-config \
  /nix/store/…-nixos-system-…

# stdin 管道（CLI 的经典形态——无 PATHS 参数且 stdin 非 TTY
# 时从 stdin 读换行分隔的路径）
nix-store -qR /nix/store/…-nixos-system-… \
  | nix run nixpkgs#cachix -- push redskaber-nix-config
```

**CLI 形态铁律**：`cachix push CACHE-NAME [PATHS...]`——**缓存名是
必选首参数**（一个 token 可服务多个缓存）；漏写时第一个 store 路径会被
静默当作缓存名（"cache not found"），无路径时 CLI 等 stdin——第 16 轮
CI push 步曾漏写，本地 CLI 验证在第 18 轮抓到并修复（该步 opt-in 保持
了它从未活跑——缺陷变门第五案的前半，pipeline.md 第 18 轮条目）。

**推送语义**（与 CI 步同源）：

- **闭包**：每个路径推其完整闭包，非单路径
- **chunk 去重**：缓存已持有的 chunk 跳过——重推是无操作，幂等
- **ZSTD**：缓存声明优先压缩法，CLI 默认遵从

**本地推送的典型场景**：owner 在 kilig-nixos 上 `just deploy` 后顺手
`just cachix-push` 把新 toplevel 推上去——CI 的下一个 run 直接替代掉
冷构建尾部（正是 38085235502 / 38385434464 两次 90 分钟超时的病灶）。
CI 侧 host-toplevels 与 darwin-toplevels 两条腿都会自动推（owner 设
`secret.CACHIX_AUTH_TOKEN` 后，opt-in，见 pipeline.md 第 16/17 轮）——
本地与 CI 推送共同维护同一缓存，互不冲突（chunk 去重兜底）。

## 边界与原则

- **分发逻辑归位分发层**：substituters 属于机器的 nix.conf（NixOS 主机
  由 platform/nixos/system/core/base/nix.nix 生成）、runner 的 extra-conf、
  或 flake 的 nixConfig 元数据（声明式缓存广告，追加式、非构建依赖）。
  构建永不依赖缓存的存在——outputs、lib、hosts 的求值对缓存零感知，
  缓存缺失时一切照常从官方源构建。
- **配额诚实账**：闭包约 1–1.5 GB ZSTD/代，锁周更 → 5 GB 免费层约
  3–4 代满。满了在 cachix.org 面板清老代；规模化出口（attic 自建 /
  harmonia 复用 kilig-nixos 零边际）见 pipeline.md 第 16 轮裁决。
- **拉取永远安全**：404 即无操作；公钥不匹配才会硬失败（那意味着
  配置错了公钥，不是缓存的问题）。

## 故障速查

| 症状 | 归因与处置 |
| --- | --- |
| `cache not found` | `cachix push` 漏了首参数缓存名——见上「CLI 形态铁律」 |
| 推送挂起不动 | 无 PATHS 且 stdin 非 TTY——CLI 在等 stdin 路径；`</dev/null` 或补显式路径 |
| `Neither auth token nor signing key` | 推送缺 token：`authtoken` 落地或 `CACHIX_AUTH_TOKEN` 环境变量 |
| 替代不发生、全部本地构建 | 检查 `nix store ping`；确认 substituters 行未被覆盖（后者优先级更高时） |
| `is not signed with any of the expected keys` | 公钥抄错——对照本文「缓存是什么」节逐字符核对 |
