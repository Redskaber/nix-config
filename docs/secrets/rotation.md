# Secrets: key hierarchy & rotation runbook (T3.3 + lifecycle verbs)

> 设计原则映射: 边界明确（user/srv 两域）· 生命周期（轮换是常态而非事故响应）·
> 最小权限（一把钥匙只开一类门）· 状态机（EMPTY → USER_ONLY → USER+HOST）。
>
> 操作面入口：`just secrets-guide`（生命周期地图）· `just secrets-status`（现状审计）。

## 1. 现状与问题

评审结论（Secrets 7.0/10）：**单一 age key 加密全部秘密文件**——
user key 同时是 `password.yaml`（用户登录密码）和五个数据库密码的
收件人。`user key 失陷 = 全部失陷`。此外 `.sops.yaml` 曾有
七条 per-path 规则，key group 完全相同——纯复制粘贴噪音。

## 2. 分层模型（本仓库已落地）

```
keys:
  &user_<name>  age1…            # 个人域: 登录密码 / github token
  &host_<alias> age1…            # 基础设施域: 只存在于 host 机器上

creation_rules:
  secrets/**/core/base/(user|nix)/**   → [ user_<name> ]               # 单 key
  secrets/**/core/srv/**               → [ host_<alias>, user_<name> ]  # 双 key
```

- **user 域**（`core/base/{user,nix}`）: 只有用户 key 能解。泄露影响面 = 个人身份。
- **srv 域**（`core/srv/`，五个 db 密码）: host key 或 user key 均可解
  （key group 语义 = 任意一把即可；要升级为 k-of-n 门槛只需给单组加多把 key，
  sops 的 `shamir_threshold` 同理）。
- **爆炸半径**: user key 失陷 ≠ 全部失陷——db 密码可轮换到只含 host key
  的新策略；host 失陷不影响 user 域（host 上没有 user 域文件的解密需求）。
- **本机双 key（own host）**: 个人机同时运行 srv 服务（dev-on-demand
  db profile）时同时消费两域——user key 解 user 域，host key 解 srv 域
  （硬化后）。age 身份文件原生多 identity，`key-install-host` 把
  host identity 合并进本机 `~/.config/sops/age/keys.txt`（sops-nix 的
  `keyFile` 本就指向它，CLI 与激活共享同一 identity 集）。
- **分发层**: 收件人由 `creation_rules` 的 path_regex 决定（第一条命中
  规则生效，与 sops 自身语义一致）。工具链只把规则当数据执行——
  `secrets-rotate.sh` 将其解析为 IR 后按序匹配，零域知识硬编码；
  keys: 别名携带域载荷（`user_*` / `host_*` 前缀），同 nix-types 枚举
  的 `.tag` 载荷行惯用法。

## 2b. 生命周期状态机与引导（bootstrap）

```
EMPTY ──just secrets-init──▶ USER_ONLY ──just key-add-host──▶ USER+HOST
EMPTY ──just secrets-init <alias> <age1…>──▶ USER+HOST   （直达双 key）
USER+HOST ──just key-remove──▶ USER_ONLY （随后 secrets-sync 重加密）
```

**EMPTY 是仓库的出厂态**（fresh clone 所见）: `.sops.yaml` 与全部密文 blob
都**不存在**——它们由 just 流程生成（`secrets-init` / `secret-set`），
用**你自己的** age key 加密后才提交入库。任何工具或他人生成的 key 材料
都无法替你完成引导（没有你的私钥就无法重加密），这正是本仓库不携带
预置密钥的原因。eval 期对 EMPTY 态宽容（`lib/shared/shared/validate.nix`
只 trace 提示引导命令；一旦树上出现任何一个 blob，声明而缺失即报错）。

模板（`docs/tmpl/sops/sops-rules.yaml.tmpl`）携带 **双渲染模式**：
user key 行无条件渲染，host key 行（`# __HOST__` 标记）由引导调用决定——

| 引导调用 | 渲染结果 | 落点状态 |
| --- | --- | --- |
| `just secrets-init` | host 行剥除（sed `/__HOST/d`） | USER_ONLY |
| `just secrets-init <alias> <age1…>` | host 行代入（keys + srv 域） | USER+HOST |

boot 之后 `.sops.yaml` 即为策略真值——`rules-init` 对已演化文件
拒绝覆盖（`rules-reset` 才会重置，防止把双域层级打回单 key）。

**新用户机引导**（全新机器，三条命令）:

```console
just init <username>        # shared.nix → hardware.nix → sops 基线
just secret-set-all         # 交互式录入全部秘密（输入即加密）
just nixos-switch nixos     # 或手工 nixos-rebuild —— 落地
```

**服务器机 day-one 直达引导**（host key 材料先行，两步取代三步）:

```console
just key-new-host <alias>          # ① 生成 keypair（仓外交付副本）
just init <username> <alias> age1… # ② 直达 USER+HOST（srv 域双收件人）
# ③ host-<alias>.age → 目标机 /var/lib/sops-nix/key.txt（chmod 400）+ shred
```

**own host = srv host（个人机双 key 落位本机，五步）**:

个人机（dev-on-demand 装载 db 服务）同时是 user 域与 srv 域的消费者。
基线态（srv 组含 user key）单把 user key 即可全解；但两条设计路径都要求
host identity 同时落位本机：**硬化策略**（srv 收件人轮换到 host-only——
直接编辑 `.sops.yaml` 的 srv key group 移除 `*user_*` 引用，然后
`secrets-sync`）后本机只有 user key 将解不开 srv blob，激活直接失败；
**独立恢复路径**（user key 在其它机器失陷/遗失时，本机 host identity 仍是
srv 域的有效解密方——key group OR 语义）。合并而非另建基础设施：

```console
just key-new-host <alias>           # ① 生成 keypair（仓外交付副本）
just key-add-host <alias> age1…     # ② 公钥接线（或 init 直达双 key）
just secrets-sync                   # ③ 存量 blob 迁移
just key-install-host <alias>       # ④ identity 合并进本机 sops key 文件
shred -u ~/Downloads/host-<alias>.age  # ⑤ 本机已持有，销毁交付副本
```

`key-install-host` 按 secret-key 行幂等（重复装跳过）、原子追加
（mktemp + cat + mv，key 文件不会中途截断）、保持 chmod 400、装完打印
本机全部 identity 公钥（`age-keygen -y` 对多 identity 文件逐行列出）。
`just secrets-status` 的 local identities 区随时审计本机持有什么。

**新 srv host 引导**（已 USER_ONLY 引导后的增量接入，四步，见 `just secrets-guide`）:

```console
just key-new-host <alias>           # ① 生成 keypair（仓外交付副本）
just key-add-host <alias> age1…     # ② 公钥接线进 .sops.yaml（srv 域）
just secrets-sync                   # ③ sops updatekeys ×N（存量 blob 迁移）
# ④ host-<alias>.age → 目标机 /var/lib/sops-nix/key.txt（chmod 400）
#    然后 shred 交付副本
```

**新 secret 三层声明**（配置层是真值，脚本只执行）:

1. `shared.nix.tmpl` 声明 dotted key → `just shared-generate <username>`
2. `docs/tmpl/sops/<rel-path>.yaml` 模板（leaf key = 路径末段，占位符
   `__SECRET_VALUE__` + `__USERNAME__`）
3. `secrets.just` 的 `_secrets-registry` 加一行
   `alias|dotted-key|prompt|transform`

注册表（registry）是唯一的别名→秘密映射：`secret-set/get/edit/remove`
与 `secrets-list` 都只是对它的薄遍历——新增秘密**零新 recipe**。

## 3. 当前状态（诚实账本）

- [x] `.sops.yaml` 分层规则 + 七合一（两条域规则）
- [x] **仓库出厂态 = EMPTY**: 旧的单 key 密文 blob 与手写的 `.sops.yaml`
      已全部移除——它们是历史评审对象，不是可部署资产（加密到他人 key 的
      密文对本仓库持有者不可解，也没有迁移义务）。
- [x] 全部生命周期动词 + 引导流（`just secrets-guide`）+ CI 门禁就绪。
- [ ] **持有者引导**（一次性，见 §2b）: `just init <username>` →
      `just secret-set-all` → 提交你自己 key 加密的 `.sops.yaml` 与 blob。
- [ ] CI 解密门禁见 §5——需要仓库 secret `SOPS_AGE_KEY`（用户 key 或两把都配）。

## 4. 操作面：just 动词总表（create / update / destroy × key / rules / blob）

| 动词 | 对象 | just 命令 | 说明 |
| --- | --- | --- | --- |
| create | key (user) | `secrets-init` | 幂等生成 ~/.config/sops/age/keys.txt |
| create | key (host) | `key-new-host <alias>` | 仓外交付副本 + chmod 400 + 接线指引 |
| create | key (host→本机) | `key-install-host <alias>` | own host 双 key：identity 合并进本机 sops key 文件（幂等/原子/保持 400） |
| create | rules | `secrets-init` | user-only 基线（存在即跳过） |
| create | blob | `secret-set <alias>` | 交互式录入（upsert 语义，覆盖即更新） |
| update | key (user) | `key-rotate-user age1…` | 引导式三步（替换→sync→接受历史暴露） |
| update | key (host) | `key-rotate-host age1…` | 引导式四步（先加后撤，无裸窗口） |
| update | rules | `key-add-host` / `key-remove` | 增量演化（模板不重生成） |
| update | blob | `secret-set <alias>` | 重新加密（同 create，overwrite） |
| update | blob (all) | `secrets-sync` | sops updatekeys 全量重加密 |
| audit | 全部 | `secrets-status` / `secrets-verify` / `secrets-list` | 钥匙/规则/blob 总览 + 一致性 + 别名表 |
| destroy | key (user) | `key-destroy` | 不可逆 |
| destroy | key (host) | `shred -u <delivery-copy>` | 交付副本销毁（目标机唯一持有） |
| destroy | rules | `rules-destroy`（+`key-remove`） | 全删 / 增量撤 |
| destroy | blob (one) | `secret-remove <alias>` | 单文件（提示配置层声明另行处理） |
| destroy | blob (all) | `secrets-destroy-all` | 全部 sops 资产（含规则与 key 文件） |

轮换模式与 `scripts/sh/secrets-rotate.sh` 一一对应：

| 模式 | 作用 | 何时 |
| --- | --- | --- |
| `check`（`just secrets-verify`） | 校验每个 blob 的 metadata 收件人 == `.sops.yaml` 规则 | CI / 日常 |
| `update`（`just secrets-sync`） | `sops updatekeys` 全量 re-encrypt 到当前规则 | 分层迁移、加 key |
| `rotate user age1…`（`just key-rotate-user`） | 生成三步走指引（替换 key → sync → 历史暴露决策） | 定期 / 疑似失陷 |
| `rotate host age1…`（`just key-rotate-host`） | 生成四步走指引（加 → sync → 撤旧 → sync） | 定期 / 疑似失陷 |

`check` 对 EMPTY 出厂态宽容（无规则无 blob → 通知并放行）；**有 blob 而无
`.sops.yaml` 是唯一致命形**（分发层消失而密文尚存——明文风险级）。

**失陷响应**（最坏情况）:

1. 撤销: `just key-remove <alias>` → `just secrets-sync`
   re-encrypt（失陷 key 从此解不开新 blob）。
2. 由于 sops 的 metadata MAC，旧 key 持有者无法伪造新 blob。
3. 数据库侧再执行一次 `ALTER USER … PASSWORD`（配置层轮换不替代数据层轮换）。

## 5. CI 门禁（`.github/workflows/ci.yml` → security stage）

- 设置仓库 secret `SOPS_AGE_KEY`（age 私钥，`AGE-SECRET-KEY-1…` 形态）。
- stage 行为: 对 `secrets/**/*.yaml` 逐个 `sops -d --output /dev/null`，
  任一解密失败 = 红。未配置 secret 时 stage 跳过（不静默成功也不阻塞）。
- **key hierarchy check（新）**: `scripts/sh/secrets-rotate.sh check` 步骤——
  ① 每个秘密文件必须被某条 creation_rule 覆盖（NO-RULE = 明文风险）
  ② blob 收件人 == 规则 key group（DRIFT = 改了规则未重加密）。
  与解密门禁互补: 解密门验证 *可解密性*，check 验证 *收件人一致性*。
- **EMPTY 出厂态宽容**: 引导前（无 `.sops.yaml`、无 blob）各校验步骤
  打印通知并放行——EMPTY 是合法入口态，不是失败态；引导后自动转严。

## 6. 为什么引导留给持有者

诚实记录（计划-现实校正）: 脚本能加密/重加密的前提是拿到 **你的私钥**。
本仓库的交付者是持有者本人——任何在持有者不知情时改写密文的行为都等于
密钥泄露。因此本仓库的边界是: **把分层规则模板、生命周期工具、CI 门禁、
文档全部铺好，让引导与轮换都成为持有者的一条命令**（`just init` /
`just secret-set-all` / `just secrets-guide`）。
