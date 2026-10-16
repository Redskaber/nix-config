# secrets multi-scenario handbook — the full just workflow

> English mirror of [docs/secrets/scenarios.md](../../secrets/scenarios.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> This document is the README's "secrets multi-scenario handbook" section (migrated
> verbatim out of the README during the T13.1 layered refactor).
> The nine scenarios cover the complete lifecycle from day one to emergency
> response; the quick-reference table and the hierarchy model are in the
> [README](../../../README.en.md#daily-operations-quick-reference).

> [Quick start](../guides/quickstart.md) is the **linear** zero-to-deploy path;
> this section is the lookup handbook organized **by scenario** — each scenario
> stands on its own, giving the goal, prerequisites, commands, the landing position
> in the state machine, and verification. All scenarios share the same map:
> `just secrets-guide`.

### Quick-reference table (one command, one intent)

| Intent | Command |
| --- | --- |
| What encrypted content do I have / what is missing | `just secrets-list` |
| Register a new secret (all three layers written in one go) | `just secrets-add <alias> <rel-path> [prompt]` |
| Change a registry row's prompt / transform | `just secrets-edit <alias> [prompt] [transform]` |
| Retire a secret (destroy the ciphertext first) | `just secrets-remove <alias>` |
| Declaration ↔ registry drift view | `just secrets-declared` |
| Enter / change a secret | `just secret-set <alias>` |
| View a secret | `just secret-get <alias>` |
| Edit a secret | `just secret-edit <alias>` |
| Enter all of them (in order) | `just secret-set-all` |
| Who can decrypt (key/rule overview) | `just secrets-status` |
| Rules ↔ ciphertext consistency | `just secrets-verify` |
| Align ciphertext after changing rules | `just secrets-sync` |
| Lifecycle map | `just secrets-guide` |

### Scenario 1 — Personal machine day one (from zero, user single key)

**Goal**: a brand-new personal machine, secrets from nothing. **Prerequisites**: Nix + just ready (Quick start Phase 0).

```bash
just init <username>     # shared.nix + hardware.nix + 密钥/规则基线（生成 user age key）
just secret-set-all      # 逐项录入（输入即加密；userpwd 需要 mkpasswd —— 见下）
just secrets-verify      # 期望: all secret blobs match the .sops.yaml hierarchy
```

```bash
# userpwd 走 mkpasswd sha-512，一次性进入工具环境再录入：
nix shell nixpkgs#mkpasswd --command just secret-set-all
```

**Landing**: `USER_ONLY`. **Verification**: `just secrets-list` (everything `set`) +
`just key-show` (record the public key in your password manager; **back up
`~/.config/sops/age/keys.txt` — it is the only decryption key of your personal
domain**). **Commit**: `.sops.yaml` (public keys, safe to commit) and
`secrets/chipr/**` (ciphertext encrypted with your key).

### Scenario 2 — Personal machine also running srv services (one machine, user + host dual key)

**Goal**: a personal machine on the dev-on-demand db profile — the same machine
consuming the user domain and the srv domain. This is the "own host = srv host"
branch: the host private key also lands **on the local machine** (the age identity
file natively holds multiple identities, and `sops-nix`'s `keyFile` already points
there).

```bash
just key-new-host <alias>              # ① 生成 host keypair（仓外交付副本 ~/Downloads）
just init <username> <alias> <age1…>   # ② 直达 USER+HOST（①打印的公钥传入）
just secret-set-all                    # ③ 录入（srv 域 blob 双收件人）
just key-install-host <alias>          # ④ host identity 合并进本机 key 文件
shred -u ~/Downloads/host-<alias>.age  # ⑤ 本机已持有 identity，销毁交付副本
```

Already bootstrapped per Scenario 1? Incremental onboarding: `just key-add-host <alias> <age1…>` →
`just secrets-sync` (existing blobs migrate to dual recipients) → `key-install-host`.

**Landing**: `USER+HOST` (the machine holds both identities). **Verification**:
`just secrets-status` (the local identities section should list both keys) +
`just secret-get postgresql` (the srv domain decrypts).

**Why step ④**: in the baseline state the single user key already decrypts the srv
domain; but both paths require the host identity to be in place — after the
**hardening policy** (rotating the srv recipients to host-only) a machine holding
only the user key will be unable to decrypt the srv blobs; the **independent recovery
path** (if the user key is compromised on another machine, this machine's host
identity remains a valid decryptor of the srv domain).

### Scenario 3 — Onboarding a remote server

**Goal**: the server (headless host) can decrypt the srv domain autonomously, no human present.

```bash
just key-new-host <alias>              # ① 服务器 keypair（你操作机上生成）
just key-add-host <alias> <age1…>      # ② 公钥接线进 .sops.yaml（srv 域）
just secrets-sync                      # ③ 存量 blob 迁移到双收件人
# ④ 交付: host-<alias>.age → 服务器 /var/lib/sops-nix/key.txt（chmod 400）
#    （服务器形态 keyFile 目标位；当前模块实现为 own-host 家目录形态——
#    详见 rotation.md 的 keyFile 落点现状注记）
#    然后 shred 交付副本 —— 目标机唯一持有
```

**Landing**: `USER+HOST`. **Verification**: on the server, `sudo sops -d
secrets/chipr/<any-srv>.yaml` (or watch sops-nix activation after deployment).
**Note**: the server does **not need** (and should not have) a user key — it decrypts
only the srv domain.

### Scenario 4 — A second personal machine (importing the existing user key)

**Goal**: the new personal machine decrypts the existing user domain. **Prerequisites**: the Scenario 1 key backup at hand.

```bash
# ① 恢复 user key（备份的 keys.txt → 新机器同路径，chmod 400）:
mkdir -p ~/.config/sops/age && cp <backup>/keys.txt ~/.config/sops/age/
chmod 400 ~/.config/sops/age/keys.txt

just init <username>                 # ② 基线（检测到 key 已存在则跳过生成）
just secrets-verify                  # ③ 既有 blob 直接收件人一致
just secret-get nix                  # 验证: user 域可解
```

**Note**: `secrets-init` is idempotent — an existing key file is not overwritten (a
private key is unrecoverable, so it is never overwritten). The rules baseline renders with
the machine's **existing** public key (read by `age-keygen -y`).

### Scenario 5 — user key rotation

**Goal**: scheduled rotation / precautionary rotation on suspected exposure.

```bash
age-keygen -o /tmp/new-user.age 2>/dev/null             # ① 新 keypair（仓外）
just key-rotate-user $(age-keygen -y /tmp/new-user.age)
# ② 脚本打印三步引导:
#    1/3 替换 .sops.yaml 中 user_* 公钥（示例给出精确行）
#    2/3 just secrets-sync        # 全量重加密到新收件人
#    3/3 提交。旧密文在 git 历史中仍可被旧 key 解——接受该暴露或重写历史
# ③ 新 key 落位本机（替换 ~/.config/sops/age/keys.txt，旧文件备份后销毁）
```

**Landing**: `USER_ONLY`/`USER+HOST` unchanged (the key changes, the layer does not).
**Verification**: `just secrets-verify` + repeat Scenario 4 on other personal
machines.

### Scenario 6 — host key rotation / revocation

**Goal**: server migration, suspected host exposure, decommissioning.

```bash
# 轮换（先加后撤，无裸窗口）:
just key-new-host <new-alias>
just key-rotate-host $(just key-show-host <new-alias>)
#    五步引导: 0/4 选旧别名 → key-add-host → secrets-sync → key-remove <old> → secrets-sync

# 撤销（退役某台 host）:
just key-remove <alias>     # 接受短名（lab → host_lab）或全名
just secrets-sync           # 失效 key 从此解不开新密文
```

**Verification**: `just secrets-status` (the keys section no longer lists the
alias) + `secrets-verify`.

### Scenario 7 — Suspected-compromise emergency

1. **Revoke**: `just key-remove <alias>` → `just secrets-sync` (the compromised key
   can never decrypt new blobs again; sops's metadata MAC prevents the old key's
   holder from forging new blobs).
2. **Assess the other domain**: the user domain and the srv domain have isolated
   blast radii ([mechanisms §5 security layer](../architecture/mechanisms.md#5-security-layer--sops--age-layered-management)) —
   which domain was compromised decides the action surface.
3. **Data-layer rotation**: a configuration-layer rotation does not replace the
   data layer — run `ALTER USER … PASSWORD` once more on the database side.
4. **git history**: old ciphertext remains decryptable in history — accept the
   exposure or rewrite history (the trade-offs of rotation.md §compromise).

### Scenario 8 — Adding a new secret (one command, all three layers written at once)

```bash
# R27 起注册表是数据文件（secrets/registry.toml），CRUD 动词一次写全三层：
#   ① registry.toml 行（别名 → dotted key → 提示语 → 变换）
#   ② 模板 YAML: docs/tmpl/sops/nixos/core/srv/db/newdb/users/__USERNAME__/password.yaml
#      （叶子键 = 路径末段；占位符 __SECRET_VALUE__ / __USERNAME__）
#   ③ shared.nix + docs/tmpl/shared.nix.tmpl 的声明行（结构化插入，保持往返等价）
just secrets-add newdb nixos/core/srv/db/newdb/users/${username}/password "NewDB password"
just secret-set newdb && just secrets-verify
# 拒绝面：路径无 .sops.yaml 规则覆盖（明文风险类）、别名/键已存在、
#        ${username} 作段内缀（无法静态命名——手工声明，见 redis 行）
```

### Scenario 9 — Destruction / decommissioning

```bash
just secret-remove <alias>     # 单个密文（shared.nix 声明另行移除——配置层真值）
just secrets-plan-destroy      # 全部明文参考实例
just rules-destroy             # .sops.yaml
just key-destroy               # 本机 user key 文件（不可逆！blob 仍在仓库）
just secrets-destroy-all       # 以上全部（明文实例+密文+规则+key 文件）
```

> Destroying the key file does not affect the ciphertext in the repository (they
> wait for **some** legitimate private key to come decrypt them); before destroying
> ciphertext, confirm that the declaration in shared.nix has also been retired —
> otherwise eval honestly reports "declared but not provided".

---
