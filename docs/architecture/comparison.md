# 同类项目对比与多方位评分 — 快照评估（2026-10-28）

> **定位与时效**：本文是一次**时点评估**（snapshot），不是 SSOT——同类仓库持续
> 演进，分数随时间衰减；复评请整表重做并更新本行日期。评估基于各仓库公开的
> README / 文档 / 仓库结构（评估日可观察事实），非逐一克隆实测。
> **评分标尺**（0–10）：0 缺失 · 3 基础（能用手搓） · 5 扎实（常规最佳实践）
> · 7 优秀（超出常见水平） · 9–10 卓越（同类中罕见 / 方法论级贡献）。

## 1. 对比对象

| 代号 | 仓库 | 选入理由 |
| ---- | ---- | -------- |
| **本仓** | redskaber/nix-config（本文主角） | 受评对象：多主机 · 编译器形状管线 · 三层策略链 |
| **starter** | misterio77/nix-starter-configs | 社区事实上的 flake 入门模板（standard/extended 两版） |
| **m77** | misterio77/nix-config | 上者的作者个人配置：多主机 · 多平台（nixos/darwin）· 库化倾向（styx 前身实践） |
| **ryan** | ryan4yin/nix-config | 中文社区最具参考度的桌面系配置：多 WM · 教程式 README |
| **gvolpe** | gvolpe/nix-config | Hyprland/niri 桌面配置 + 博客配套（nix-config 系列教程） |
| **mic92** | Mic92/nix-config | sops-nix 作者的个人配置：极简 · 密钥管理权威实践 |

选样覆盖四类形态：**模板**（starter）、**教学型个人配置**（ryan · gvolpe）、
**工程师个人配置**（m77 · mic92）、**平台工程型个人配置**（本仓）。

## 2. 相同点（共同基因）

六个仓库共享 NixOS 生态 2026 年的「事实标准栈」——这些相同点构成对比基线：

1. **Flakes 作为组织单位** —— 全部以 flake.nix 为入口，flake.lock 锁定
   nixpkgs revision（可复现性基线一致）。
2. **Home Manager 纳管用户域** —— 全部集成 HM（standalone 或 module mode），
   dotfile 声明化。
3. **多主机目录** —— hosts/（或等价物 machines/）按目录分机器，flake 输出
   按主机名寻址（本仓/m77/mic92 均为 readDir 自动发现，ryan/starter 为
   手写清单）。
4. **渠道纪律** —— stable/unstable 双通道或多通道消费（程度不同，方向一致）。
5. **密钥声明化** —— sops-nix 或等价（agenix）管理 secret（mic92 是 sops-nix
   作者本人；本仓为双域密钥层级）。
6. **devShells** —— 均以 flake devShells 提供开发环境（深浅不一）。

## 3. 评分矩阵（16 维度）

| # | 维度 | 本仓 | starter | m77 | ryan | gvolpe | mic92 |
| - | ---- | ---- | ------- | --- | ---- | ------ | ----- |
| 1 | 多主机清单与分发 | 9 | 3 | 7 | 5 | 3 | 7 |
| 2 | 策略分层与抽象 | 10 | 4 | 6 | 4 | 3 | 4 |
| 3 | 类型安全与校验 | 9 | 2 | 3 | 2 | 2 | 2 |
| 4 | 测试深度与结构 | 9 | 1 | 4 | 2 | 1 | 3 |
| 5 | CI/CD 完备性 | 9 | 4 | 6 | 3 | 3 | 4 |
| 6 | 文档体系 | 10 | 8 | 6 | 8 | 6 | 3 |
| 7 | 密钥管理 | 8 | 1 | 5 | 4 | 2 | 8 |
| 8 | 部署通道 | 8 | 2 | 6 | 3 | 2 | 5 |
| 9 | 可复现性与锁定纪律 | 9 | 6 | 8 | 6 | 6 | 8 |
| 10 | 跨平台覆盖 | 9 | 4 | 8 | 3 | 2 | 4 |
| 11 | 模块化与可复用性 | 8 | 7 | 7 | 5 | 4 | 5 |
| 12 | 开发体验 | 9 | 5 | 6 | 5 | 5 | 4 |
| 13 | 新手可采纳性 | 4 | 10 | 6 | 9 | 7 | 5 |
| 14 | 缓存与构建效率策略 | 8 | 4 | 5 | 4 | 3 | 4 |
| 15 | 代码卫生 | 10 | 6 | 6 | 5 | 5 | 6 |
| 16 | 社区规模与生态影响 | 3 | 8 | 6 | 8 | 6 | 8 |
| | **合计（/160）** | **132** | **75** | **89** | **71** | **54** | **82** |

（合计仅供排序直觉；维度间不可互换——本仓 16 维低分项恰是其定位使然，见 §5。）

## 4. 分维度详评

**D1 多主机清单与分发** —— 本仓 9：readDir 清单 → caps 能力表分类 → 四
发射器（含 colmena 部署面）+ Law E/G 命名普查（加机器 = 注册表一行 + mkdir，
零 flake.nix 改动）。m77 7：清单完备但主机属性手写枚举；mic92 7：自动发现

+ 部署脚本朴素有效。starter 3：模板展示双主机写法，不分发。

**D2 策略分层与抽象** —— 本仓 10：fleet → role → host 三层受控合并 +
Law F 白名单 + `why` 逐键溯源 + 分层 schema（fleet 16 / shared 18），
role 以「策略束」实现组合优于覆写（Kustomize 教义）。m77 6：有 shared
抽象与 opts 库化萌芽；其余 3–4：平铺 attrset 或简单共用模块。

**D3 类型安全与校验** —— 本仓 9：nix-types ADT（enum 构造即穷尽 · Option/
Result 铁路）+ schema 解构校验器 + i18n 双源守卫。其余 1–3：靠 Nix 惰性
eval 失败兜底（生态常态——这正是本仓的差异化投注）。

**D4 测试深度** —— 本仓 9：6 平面 103 tests + 6 卫生门 = 109 checks
（QEMU VM 级 + nmt 零 VM 断言 + eval 深度普查），计数锚点机器强制。
m77 4：有基本 CI 检查；mic92 3：少量测试；ryan/gvolpe/starter 1–2：近乎
无测试（dotfile 配置的生态常态）。

**D5 CI/CD 完备性** —— 本仓 9：10 阶段（lint → 面分片深评 → vm-tests →
闭包级 → darwin 腿 → summary 对账）+ 每周自动 flake 更新 PR + opt-in 缓存
推送。m77 6：多平台矩阵 CI；其余 2–4。

**D6 文档体系** —— 本仓 10：双语镜像平面（结构奇偶性 + CJK 纯度由门强制）

+ docs-ssot 计数锚点 + TOC 导航电池 + 十一层机制深度版 + 管线参考卡
（pipeline.md）。starter 8：模板文档即产品，注释密度极高；ryan 8：教程式
README 对新手极友好；mic92 3：极简 README（自觉选择）。

**D7 密钥管理** —— mic92 8：sops-nix 作者本人，权威但朴素；本仓 8：双域
密钥层级状态机（user/host）+ 注册表驱动 + 模板渲染 + 轮换 runbook + 九情景
手册——工程化更深，但权威性不如上游作者。starter/gvolpe 1–2：不管或留白。

**D8 部署通道** —— 本仓 8：nixos-rebuild / home-switch / colmena 0.5
三通道 + 部署事实与 census law（deploy.nix 挂非 NixOS 主机即 eval throw）。
m77 6：nixos-rebuild + darwin-rebuild 全覆盖；mic92 5：脚本化部署。

**D9 可复现性** —— mic92/m77 8：锁定纪律严格；本仓 9：47 inputs 全锁定
（tarball 精确 rev 或 follows 收敛）+ nix-types WHAT/WHERE 双侧钉（lock 答
WHERE、tests 答 WHAT，单侧漂移即红）+ roundtrip 字节等价门。ryan/starter/
gvolpe 6：标准 flake.lock。

**D10 跨平台覆盖** —— 本仓 9：nixos · darwin（aarch64）· wsl（standalone）
· nixos-wsl（双门）· generic-linux 五形态，跨系统求值验证。m77 8：
nixos + darwin + 通用 Linux。其余 2–4：单平台或双平台。

**D11 模块化与可复用性** —— starter 7：模板本身就是可复用产物；本仓 8：
export/ 可上游模块（nixosModules/homeModules 双输出 + 接口规范文档）+
overlays/pkgs 纪律 + 可达性门防死代码；m77 7：opts 库化实践。其余 4–5。

**D12 开发体验** —— 本仓 9：25 个 pdshell 组合式 devShells（combinFrom
复合 + 生命周期四钩子）+ 98 recipe × 14 组 just 参考表 + 服务按需启停动词。
m77/ryan 5–6：标准 devShell + 常规脚本；mic92 4：make/shell 脚本。

**D13 新手可采纳性** —— starter 10：为此而生；ryan 9：教程式文档 + 中文
社区答疑；gvolpe 7：博客配套。**本仓 4**：方法论密度高（三层链 · 六法则 ·
门禁家族），fork 者需要先理解「一个编译器」的心智模型——自觉的取舍：
本仓为「平台工程型」配置，不是入门模板。

**D14 缓存与构建效率** —— 本仓 8：fleet 缓存身份 SSOT 三面按值分发 +
入口层法定沉默（cache-ssot 门）+ nix-fast-build 平面整面交接 + opt-in
attic 推送。其余 3–5：默认 substituters 或 cachix 单点。

**D15 代码卫生** —— 本仓 10：pre-commit（nixfmt/statix/deadnix）+
模块可达性门 + 文法门 + testScript 语法门 + docs-ssot + en-parity +
cache-ssot 六门家族（死代码对门不可见的类别根治——run #369 类事故的
结构性防御）。其余 5–6：常规 pre-commit 或无。

**D16 社区与生态影响** —— starter/mic92 8（模板被大量引用 / sops-nix 是
生态基础设施）· ryan 8（中文社区最大参考度之一）· m77/gvolpe 6。
**本仓 3**：单维护者个人仓库，暂无社区外溢——最大差距项，见 §5。

## 5. 综合定位

**本仓的自我定位**：把个人 NixOS 配置当作**平台工程项目**来做——用编译器
形状的管线（源 → 前端 → 合并 → IR → codegen → 链接 → 装载）替代
「一个大 attrset」，用机器强制的法则与门禁家族替代口头纪律。这在同类
个人配置中是**方法论级差异**（D2/D3/D4/D15 的 9–10 分来源），代价是
D13/D16 的低分：学习曲线陡峭、无社区外溢、单点维护风险。

**与各对象的一句话关系**：

+ 对 **starter**：互补而非竞争——本仓是「starter 毕业后的第二站」；
  理想的采纳路径是 starter 入门 → m77/ryan 练手 → 需要治理多主机多平台
  时评估本仓的方法论。
+ 对 **m77**：精神上最接近的同路者（库化 · 多平台 · 自动发现），本仓
  在其方向上走得更远（类型系统 + 门禁家族 + 三层策略链）。
+ 对 **ryan**：文档教学面相反的镜像——ryan 面向入门者拉平曲线，本仓面向
  工程师拉高天花板；ryan 的社区运营值得学习。
+ 对 **gvolpe**：桌面体验深度的对照（gvolpe 的 Hyprland/niri 手工打磨
  vs 本仓的策略束驱动——本仓 wm 树按 enum 形态切换，牺牲手揉细节换
  一键换形态）。
+ 对 **mic92**：密钥管理与极简主义的对照——mic92 证明个人配置可以
  「小而正确」；本仓选择「大而自证」（每个结构声明配一个门）。两者
  是光谱两端，无优劣。

**诚实的短板清单**（按修复优先级）：

1. **无社区**（D16=3）：无 issue 模板 / CONTRIBUTING / 外部贡献者先例。
2. **新手门槛**（D13=4）：缺「最小可用子集」的入门路径（quickstart 面向
   全量引导，不是渐进式）。
3. **单维护者总线系数 = 1**：方法论密度本身是理解税。
4. **构建级测试依赖 KVM/CI**：沙箱/无 KVM 环境只能跑 eval 深度（本仓
   已用「断言内插进 testScript」部分缓解——eval 即执行断言）。
5. **桌面手揉深度**：wm 主题栈以策略束参数化为主，不如 gvolpe/ryan 的
   手工打磨细。

## 6. 交叉学习清单（从同类项目可借鉴项）

| 来源 | 可借鉴项 | 落点建议 |
| ---- | -------- | -------- |
| starter | 最小可用模板抽取 | 从本仓抽取「三层链最小示例」作为 docs/guides/ 的渐进教程（quickstart 已有骨架，可加「三层最小集」） |
| ryan | 教程式文档 + 社区运营 | README 增加图解版管线（当前 ASCII 图对新手偏密）；开放 issue 模板 |
| m77 | opts 库上游化路径 | export/ 模块持续上游化（interface-standards.md 已定契约） |
| mic92 | 极简主义审计 | 定期自问「这个门/法则能否退役」——机制预算审查（本仓 §5 短板 3 的缓解） |
| gvolpe | 博客化输出 | 十一层机制文档可抽博客系列（对外输出 = D16 的唯一可行解法） |

---

*评估方法备忘：分数由仓库公开结构推导（目录形状 · CI workflow · 测试目录 ·
文档规模），跨仓库同标尺打分；「本仓」列基于本文档所在 HEAD 的实际状态
（109 checks 全绿、双语文档平面、六门家族在位）。对同类的描述如有失准，
以各仓库官方 README 为准——本文不锁死它们的未来。*
