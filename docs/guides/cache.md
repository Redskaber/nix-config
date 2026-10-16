# 缓存指南 — 本地拉取与推送（redskaber-nix-config 公开层）

> 本文覆盖 CI 之外的本地工作流：**拉取**（任何机器，零鉴权）与**推送**
> （owner 侧动词，需 auth token）。CI 侧的接线（PULL ×11 腿 extra-conf +
> PUSH 两步）见 [.github/workflows/ci.yml](../../.github/workflows/ci.yml) 与
> [README 的 CI/CD 节](../../README.md#cicd-完整执行流)；两份文档
> 同源不同受众：CI 文法回答「为什么这样设计」，本文回答
> 「我的机器怎么用这个缓存」。

## 缓存是什么（一段话）

公开 Cachix 缓存 `redskaber-nix-config`（ZSTD、priority 41、公钥
`redskaber-nix-config.cachix.org-1:ziIAJzLVe11AexFTrAY3IZVTZQOWUa5vmFB3eeaW8zw=`）。
它只服务一件事：**锁钉在 nixos-26.05 移动分支 HEAD 造成的 Hydra 缺口**——
锁快于渠道二进制进度，冷 run 的闭包构建尾部（历史实测 1h+）在本缓存
有内容后塌缩为替代下载。priority 41 保持在 cache.nixos.org（40）之后：
两边都有的路径永远走官方——免费层 5GB 只花在官方追不上的缺口上。

**身份单源（SSOT）**：缓存身份（名/URL/公钥）只声明在
`lib/shared/lang/const.nix`（`shared.const.cache.fleet`），分发按各面能力：
nix 消费面**按值消费**——platform/nixos/system/core/base/nix.nix 主机侧组合、
platform/darwin/system/nix（darwin 主机侧）与 home/core/base/nix.nix
（第 30 轮新增的 standalone 用户平面，caps.system-nix 门控）都
引用 `shared.const.cache.fleet`，不可能漂移；无法求值的面持**钉死的字面
量镜像**——CI workflows、scripts/just/cachix.just（YAML/shell 面无法 import
nix）与本文档的散文。flake.nix **不携带**任何缓存身份（第 27 轮裁决：
入口层零缓存身份——真实消费面〔主机 ×3 + CI〕已全部闭合，flake 级字面
量将是唯一「能求值 const 却持字面量」的镜像面，且 nixConfig 的信任语义
对外部消费者是负债而非服务——accept 提示摩擦 + 非受信用户下静默忽略；
无主机侧 nix.conf 的消费者按本文三种拉取形式显式接入）。
第六个仓库卫生门 `tests/cache-ssot.nix` 把每个镜像钉到 const 值上，并把
flake.nix 的沉默钉为断言（任何 nixConfig 回归即 CI 红灯）。

**客户端覆盖优先级**：如需本缓存绝对先行（官方也有的路径也从这里取），
可在 substituters 的 URL 后追加 `?priority=30`（nix 的 per-URL priority
覆盖，小于 40 即排到 cache.nixos.org 之前）——默认不这样做：查询顺序
由各缓存自报的 priority 主导（列表位置只是平级时的次序），41 的定位
是把免费层配额留给官方追不上的缺口。

## 拉取（任何机器，无需 token）

机器常驻的两种等价形式，落点都是机器的 nix.conf；会话作用域的第三形式（零落盘）见本节末：

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

**形式三：会话作用域**（NIX_CONFIG 环境变量——零落盘，一条命令的
进程树即全部作用域）

```bash
NIX_CONFIG="
substituters = https://redskaber-nix-config.cachix.org https://cache.nixos.org
trusted-public-keys = redskaber-nix-config.cachix.org-1:ziIAJzLVe11AexFTrAY3IZVTZQOWUa5vmFB3eeaW8zw= cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
" nix build github:Redskaber/nix-config#checks.x86_64-linux.module-reachability-check
```

nix 配置优先级链的最顶层：NIX_CONFIG 遮蔽一切文件配置（用户文件、
系统文件全部让位）——因此该形式携带的是**完整**两行而非追加。若想
在保留内置默认（cache.nixos.org 及其公钥）的前提下仅追加本缓存，
用列表型设置的追加形态：`extra-substituters = https://redskaber-nix-config.cachix.org`
+ `extra-trusted-public-keys = redskaber-nix-config.cachix.org-1:ziIAJzLVe11AexFTrAY3IZVTZQOWUa5vmFB3eeaW8zw=`
（一对 extra-* 与上面的完整两行等价——内置默认本就只有官方源）。
三个消费场景：一次性环境（CI 式容器 / 沙箱会话）零落盘；借用他人
机器不改任何配置；先体验缓存收益再决定是否常驻（升级到形式一/二）。

**验证拉取配置生效**：

```bash
nix store ping --store https://redskaber-nix-config.cachix.org
# 缓存为空时 narinfo 404 是无害空操作，nix 自然回退 cache.nixos.org
```

拉取**不需要** auth token——公开缓存零鉴权。这也是 CI 侧 PULL
无条件 ×11 腿成立的原因（见 [.github/workflows/ci.yml](../../.github/workflows/ci.yml)
各腿的 Install Nix extra-conf 钉版）。

**darwin 主机运行时注意**：darwin-rebuild 用的是 /etc/nix/nix.conf——
平台侧 platform/darwin/system/nix 生成它（nix-darwin 的 nix 模块，与
NixOS 主机同一身份单源：shared.const.cache.fleet 按值消费，拉取侧四面
闭合：CI runner · NixOS 主机 · darwin 主机 · standalone 用户平面；flake
入口层不携带缓存身份，见上「身份单源」）。nix-darwin 按已知哈希白名单
接管安装器版的 /etc/nix/nix.conf，switch 即落盘；非本 flake 管理的 darwin
机器仍走形式一/二。

**standalone 用户平面（第 30 轮）**：hosts/wsl 这类无系统层的
standalone-HM 主机，fleet 无法触达 /etc/nix/nix.conf——共享树
home/core/base/nix.nix 经 home-manager 原生 `nix.settings` 渲染
~/.config/nix/nix.conf（+ registry.json），同一身份按值消费、同一套
experimental-features。注意两点：① nix.conf 优先级链中用户文件按设置
遮蔽系统文件（列表型整体替换），故该平面仅在无系统 nix 平台的形态渲染
（caps.system-nix 门控，nixos/darwin 主机保持系统平面单一）；② 守护进程
形态下用户级 substituters 生效需用户受信（单用户安装无此前提）——信任
是发行版侧的机器属性，与 NixOS 主机侧 trusted-users 同源问题。

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
静默当作缓存名（"cache not found"），无路径时 CLI 等 stdin——CI push
步曾漏写，本地 CLI 验证抓到并修复（该步 opt-in 保持
了它从未活跑——缺陷变门第五案的前半，cache-ssot 门现把 CI 文件的
缓存名/URL/公钥三字面量钉为镜像断言）。

**推送语义**（与 CI 步同源）：

- **闭包**：每个路径推其完整闭包，非单路径
- **chunk 去重**：缓存已持有的 chunk 跳过——重推是无操作，幂等
- **ZSTD**：缓存声明优先压缩法，CLI 默认遵从

**本地推送的典型场景**：owner 在 kilig-nixos 上 `just deploy` 后顺手
`just cachix-push` 把新 toplevel 推上去——CI 的下一个 run 直接替代掉
冷构建尾部（正是 38085235502 / 38385434464 两次 90 分钟超时的病灶）。
CI 侧 host-toplevels 与 darwin-toplevels 两条腿都会自动推（owner 设
`secret.CACHIX_AUTH_TOKEN` 后 opt-in 生效——已知边界台账 #3 追踪）——
本地与 CI 推送共同维护同一缓存，互不冲突（chunk 去重兜底）。

## 边界与原则

- **分发逻辑归位分发层**：substituters 属于机器的 nix.conf（NixOS 主机
  由 platform/nixos/system/core/base/nix.nix、darwin 主机由
  platform/darwin/system/nix、standalone-HM 主机由
  home/core/base/nix.nix〔用户级 ~/.config/nix/nix.conf，第 30 轮〕
  生成）或 runner 的 extra-conf——flake.nix
  入口层不携带缓存身份（第 27 轮裁决，见上「身份单源」；门把沉默钉为
  断言）。缓存身份本身单源在 lib/shared/lang/const.nix，按各面能力分发
  （见上「身份单源」）。构建永不依赖缓存的存在——outputs、lib、hosts 的
  求值对缓存零感知，缓存缺失时一切照常从官方源构建。
- **配额诚实账**：闭包约 1–1.5 GB ZSTD/代，锁周更 → 5 GB 免费层约
  3–4 代满。满了在 cachix.org 面板清老代；规模化出口（attic 自建 /
  harmonia 复用 kilig-nixos 零边际）见
  [.github/workflows/cache-attic.yml](../../.github/workflows/cache-attic.yml)
  （attic 双轨预案，vars 门控）。
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
