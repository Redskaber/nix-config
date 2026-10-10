# secrets 多情景手册 — just 全流程

> 本文是 README「secrets 多情景手册」节（T13.1 分层重构时从 README 原样迁出）。
> 九个情景覆盖 day-one 到应急的完整生命周期；速查表与层级模型见
> [README](../../README.md#日常操作速查)。

> [快速开始](../guides/quickstart.md) 是**线性**的从 0 到部署路径；
> 本节是**按情景**的查阅手册——每个情景独立成立，给出目标、前置、命令、
> 落点状态机位置与验证。所有情景共享同一张地图：`just secrets-guide`。

### 速查表（一条命令一个意图）

| 意图 | 命令 |
| --- | --- |
| 我有哪些加密内容 / 缺哪个 | `just secrets-list` |
| 录入 / 改一个秘密 | `just secret-set <alias>` |
| 看一个秘密 | `just secret-get <alias>` |
| 编辑一个秘密 | `just secret-edit <alias>` |
| 全部录入（顺序） | `just secret-set-all` |
| 谁能解密（钥匙/规则总览） | `just secrets-status` |
| 规则 ↔ 密文一致性 | `just secrets-verify` |
| 改了规则后对齐密文 | `just secrets-sync` |
| 生命周期地图 | `just secrets-guide` |

### 情景 1 — 个人机 day-one（从 0，user 单 key）

**目标**: 全新个人机，secrets 从无到有。**前置**: Nix + just 就绪（快速开始 Phase 0）。

```bash
just init <username>     # shared.nix + hardware.nix + 密钥/规则基线（生成 user age key）
just secret-set-all      # 逐项录入（输入即加密；userpwd 需要 mkpasswd —— 见下）
just secrets-verify      # 期望: all secret blobs match the .sops.yaml hierarchy
```

```bash
# userpwd 走 mkpasswd sha-512，一次性进入工具环境再录入：
nix shell nixpkgs#mkpasswd --command just secret-set-all
```

**落点**: `USER_ONLY`。**验证**: `just secrets-list`（全部 `set`）+
`just key-show`（把公钥记录到密码管理器；**备份 `~/.config/sops/age/keys.txt`——
它是你个人域唯一的解密钥匙**）。**提交**: `.sops.yaml`（公钥，可入库）与
`secrets/chipr/**`（你的 key 加密的密文）。

### 情景 2 — 个人机同时跑 srv 服务（一台机器，user + host 双 key）

**目标**: dev-on-demand db profile 的个人机——同一台机器消费 user 域与
srv 域。这是「own host = srv host」分支：host 私钥也落位**本机**
（age 身份文件原生多 identity，`sops-nix` 的 `keyFile` 本就指向它）。

```bash
just key-new-host <alias>              # ① 生成 host keypair（仓外交付副本 ~/Downloads）
just init <username> <alias> <age1…>   # ② 直达 USER+HOST（①打印的公钥传入）
just secret-set-all                    # ③ 录入（srv 域 blob 双收件人）
just key-install-host <alias>          # ④ host identity 合并进本机 key 文件
shred -u ~/Downloads/host-<alias>.age  # ⑤ 本机已持有 identity，销毁交付副本
```

已按情景 1 引导过？增量接入：`just key-add-host <alias> <age1…>` →
`just secrets-sync`（存量 blob 迁移到双收件人）→ `key-install-host`。

**落点**: `USER+HOST`（本机持双 identity）。**验证**: `just secrets-status`
（local identities 应列出两把）+ `just secret-get postgresql`（srv 域可解）。

**为什么要 ④**: 基线态单把 user key 已可解 srv 域；但两条路都要求 host
identity 就位——**硬化策略**（srv 收件人轮换到 host-only）后本机只有
user key 将解不开 srv blob；**独立恢复路径**（user key 在其它机器失陷时，
本机 host identity 仍是 srv 域有效解密方）。

### 情景 3 — 接入远程服务器

**目标**: 服务器（headless host）能自主解密 srv 域，无需人在场。

```bash
just key-new-host <alias>              # ① 服务器 keypair（你操作机上生成）
just key-add-host <alias> <age1…>      # ② 公钥接线进 .sops.yaml（srv 域）
just secrets-sync                      # ③ 存量 blob 迁移到双收件人
# ④ 交付: host-<alias>.age → 服务器 /var/lib/sops-nix/key.txt（chmod 400）
#    然后 shred 交付副本 —— 目标机唯一持有
```

**落点**: `USER+HOST`。**验证**: 服务器上 `sudo sops -d
secrets/chipr/<任一srv>.yaml`（或部署后看 sops-nix 激活）。
**注意**: 服务器**不需要**（也不应有）user key——它只解 srv 域。

### 情景 4 — 第二台个人机（既有 user key 导入）

**目标**: 新个人机解密既有 user 域。**前置**: 情景 1 的 key 备份在手。

```bash
# ① 恢复 user key（备份的 keys.txt → 新机器同路径，chmod 400）:
mkdir -p ~/.config/sops/age && cp <backup>/keys.txt ~/.config/sops/age/
chmod 400 ~/.config/sops/age/keys.txt

just init <username>                 # ② 基线（检测到 key 已存在则跳过生成）
just secrets-verify                  # ③ 既有 blob 直接收件人一致
just secret-get nix                  # 验证: user 域可解
```

**注意**: `secrets-init` 幂等——key 文件已存在时不覆盖（私钥不可恢复，
永不覆写）。规则基线渲染会用**本机现有**公钥（`age-keygen -y` 读取）。

### 情景 5 — user key 轮换

**目标**: 定期轮换 / 疑似暴露的预防性轮换。

```bash
age-keygen -o /tmp/new-user.age 2>/dev/null             # ① 新 keypair（仓外）
just key-rotate-user $(age-keygen -y /tmp/new-user.age)
# ② 脚本打印三步引导:
#    1/3 替换 .sops.yaml 中 user_* 公钥（示例给出精确行）
#    2/3 just secrets-sync        # 全量重加密到新收件人
#    3/3 提交。旧密文在 git 历史中仍可被旧 key 解——接受该暴露或重写历史
# ③ 新 key 落位本机（替换 ~/.config/sops/age/keys.txt，旧文件备份后销毁）
```

**落点**: `USER_ONLY`/`USER+HOST` 不变（换钥不换层级）。**验证**:
`just secrets-verify` + 其它个人机重复情景 4。

### 情景 6 — host key 轮换 / 撤销

**目标**: 服务器迁移、host 疑似暴露、退役。

```bash
# 轮换（先加后撤，无裸窗口）:
just key-new-host <new-alias>
just key-rotate-host $(just key-show-host <new-alias>)
#    四步引导: key-add-host → secrets-sync → key-remove <old> → secrets-sync

# 撤销（退役某台 host）:
just key-remove <alias>     # 接受短名（lab → host_lab）或全名
just secrets-sync           # 失效 key 从此解不开新密文
```

**验证**: `just secrets-status`（keys 区不再列出该别名）+ `secrets-verify`。

### 情景 7 — 疑似失陷应急

1. **撤销**: `just key-remove <alias>` → `just secrets-sync`（失陷 key
   从此解不开新 blob；sops 的 metadata MAC 使旧 key 持有者无法伪造新 blob）。
2. **另一域评估**: user 域与 srv 域爆炸半径隔离（[mechanisms §5 安全层](../architecture/mechanisms.md#5-安全层--sops--age分层管理)）——按失陷的
   是哪个域决定动作面。
3. **数据层轮换**: 配置层轮换不替代数据层——数据库侧再执行
   `ALTER USER … PASSWORD`。
4. **git 历史**: 旧密文仍在历史中可解——接受暴露或重写历史
   （rotation.md §compromise 的权衡）。

### 情景 8 — 新增一个 secret（三层，配置层是真值）

```bash
# ① shared.nix.tmpl 声明 dotted key（重新生成 shared.nix）:
#    nixos.core.srv.db.newdb.user.password = "nixos/core/srv/db/newdb/users/__USERNAME__/password";
# ② 模板 YAML: docs/tmpl/sops/nixos/core/srv/db/newdb/users/__USERNAME__/password.yaml
#    （叶子键 = 路径末段；占位符 __SECRET_VALUE__ / __USERNAME__）
# ③ 注册表一行: secrets.just::_secrets-registry
#    'newdb|nixos.core.srv.db.newdb.user.password|NewDB password|plain'
just shared-generate <username> && just secret-set newdb && just secrets-verify
```

### 情景 9 — 销毁 / 退役

```bash
just secret-remove <alias>     # 单个密文（shared.nix 声明另行移除——配置层真值）
just secrets-plan-destroy      # 全部明文参考实例
just rules-destroy             # .sops.yaml
just key-destroy               # 本机 user key 文件（不可逆！blob 仍在仓库）
just secrets-destroy-all       # 以上全部（明文实例+密文+规则+key 文件）
```

> 销毁 key 文件不影响仓库中的密文（它们等着**某把**合法私钥来解）；
> 销毁密文前确认 shared.nix 中的声明也已退役，否则 eval 期
> 「declared but not provided」会如实报错。

---
