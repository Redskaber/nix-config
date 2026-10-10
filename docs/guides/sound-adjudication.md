# sound 轴裁决卷宗 — 债 #9 语义半部（T17.1）

> 本文是 README 已知债务 #9「语义半部」的裁决卷宗：控制台主机的 sound
> 策略行翻转所需的证据清单、架构事实、裁决矩阵与**预裁决的一行翻转**。
> 机械半部已由 T10.1 落地（独立策略轴 + `pipewire`/`none` 枚举 +
> `nixos_core_base_sound_gate` 双律锁定）；本卷宗把剩余的环境门控部分
> 从「等待真机」推进为「到机即决」——证据采集有专用动词
> （`just sound-audit`），裁决结论已预写（§4），翻转行已在两台主机的
> shared.nix 中以注释形式预置。

## 1. 裁决范围

sound 轴是 NixOS 系统层策略（`platform/nixos/core/base/sound.nix` 读
`shared.sound.value.sound-server` 门控），因此只有路由进 nixosConfigurations
的主机需要回答本轴：

| 主机 | 形态 | 裁决状态 |
| --- | --- | --- |
| `nixos` | 裸金属工作站（hyprland + ly 桌面会话） | **无需裁决**——基策略 `pipewire` 即正确行（桌面会话消费本地声音栈） |
| `vm` | QEMU 客机，server-form 控制台 | **待裁决**（§2 证据 A） |
| `nixos-wsl` | WSL2 发行版，本仓拥有系统层 | **待裁决**（§3 证据 B） |
| `wsl` | standalone HM（系统层非本仓所有） | 出范围——sound 模块从不进入其闭包，轴值不被消费 |
| `darwin` | nix-darwin 平台树 | 出范围——sound.nix 是 platform/nixos 专属 |

## 2. 证据 A — `vm`（QEMU 音频设备）

### 架构事实

1. **客机的音频设备是域定义的产物，不是必然存在的**：裸
   `qemu-system-x86_64` 不加 `-device`/`-audiodev` 时客机内没有任何
   音频硬件；libvirt/virt-manager 域模板则常默认挂 `ich9-intel-hda`
   （Red Hat Bugzilla #1140937 起的长期形态）。即：**启动器的域定义
   是仲裁者，而启动器在本仓之外**——这正是该裁决被环境门控的原因。
2. **本仓的声明侧已经回答了一半**：`hosts/vm/facter.json`（T5.12
   声明式硬件事实）的 `hardware` 键只有 `cpu` / `disk` /
   `storage_controller` / `network_controller`——**没有音频设备**。
   声明与探测的差异正是真机审计要闭合的缺口（virt-manager 默认域
   会挂 hda 设备，探测会立刻暴露）。
3. **无 ALSA 卡时本地声音服务器无事可中介**：pipewire 全栈
   （rtkit + alsa 层 + wireplumber + mixer 工具带）服务的是声卡枚举；
   `/proc/asound/cards` 为空即证明整栈零负载。
4. 机器故事（T7.2 裁决）是 server-form 维护机：wm/dm 皆 none、
   service-profile `server-pg-only`、app-set `none`——即使启动器挂了
   音频设备，该故事也不预置音频消费。

### 探针（在已启动的 VM 内执行）

```bash
just sound-audit          # 本卷宗的机械采集动词（只读；下述探针的封装）
# 或手动等价：
lspci -nn | grep -iE 'audio|multimedia'   # PCI 音频设备存在性
cat /proc/asound/cards                    # ALSA 卡枚举（空 = 无卡）
ls /dev/snd 2>/dev/null                   # 设备节点
```

### 裁决矩阵

| 探针结果 | 裁决 | 依据 |
| --- | --- | --- |
| 无 PCI 音频设备 + 无 ALSA 卡 | **`none`** | 声明（facter）与探测一致；本地声音服务器零硬件可中介 |
| 有音频设备（如 ich9-intel-hda） | **`none`（预裁决不变）**，除非所有者明确要经显示通道（SPICE/VNC）发声才翻 `pipewire` | 机器故事（server-form）拥有该裁决；设备存在 ≠ 音频消费意图 |

## 3. 证据 B — `nixos-wsl`（WSLg 的 Windows 侧 pulse 桥）

### 架构事实（一手来源：microsoft/wslg README「WSLg System Distro」节）

1. **音频中介运行在 system distro，不在用户发行版**：「The system
   distro is a containerized Linux environment where the WSLg XServer,
   Wayland server and Pulse Audio server are running. Communication
   socket for each of these servers are projected into the user
   distro…」——用户发行版（NixOS-WSL）消费的是投影 socket。
2. **`PULSE_SERVER` 由 WSLg 预配置**：「We preconfigure the user distro
   environment variables DISPLAY, WAYLAND_DISPLAY and PULSE_SERVER to
   refer these servers by default」——WSLg 会话内的音频客户端被路由
   到 Windows 侧，**无论本地是否另跑声音服务器**。
3. **音频数据经 RDP 通道往返**（`module-rdp-sink`/`module-rdp-source`）；
   用户发行版内核不向 guest 暴露音频硬件——本地 pipewire 在 WSL 内
   没有任何 ALSA 卡可服务，且在 WSLg 会话内因 `PULSE_SERVER` 覆盖而
   不会被客户端选中：**纯死重**。
4. WSLg 可经 `.wslconfig` 关闭——关闭后连 Windows 侧服务器都不存在
   （音频路径整体消失），本地栈依然无事可做。
5. **SSH 会话不继承 WSLg 环境**：`PULSE_SERVER` 未设的会话里，
   客户端回落到本地默认 socket。对维护型控制台而言「SSH 会话无音频」
   是 `none` 行的正确语义，不是缺陷（如需 SSH 会话音频，那是把
   `PULSE_SERVER` 指向 wslg socket 的会话级配置问题，不是安装本地
   服务器的理由）。

### 探针（在 WSL 发行版内执行；须从 WSLg 终端会话运行——SSH 会话不继承 WSLg env）

```bash
just sound-audit                        # 机械采集（只读）
# 或手动等价：
test -S /mnt/wslg/PulseServer && echo socket-present
echo "PULSE_SERVER=${PULSE_SERVER:-<unset}"
```

（`pactl info` 可选：需要 pulseaudio 工具集，lean 控制台档案不携带；
socket + env 两探针已足以裁决。）

### 裁决矩阵

| 探针结果 | 裁决 | 依据 |
| --- | --- | --- |
| socket 存在 + `PULSE_SERVER` 已设 | **`none`** | 音频中介归宿主环境——枚举 `none` 行自己的契约注释（T10.1 成文时即预写了这一答案） |
| WSLg 关闭 / socket 缺失 | **`none`** | 音频路径整体不存在，本地栈无事可做 |

两条行的裁决相同——该主机的证据只影响注释里的归因措辞，不影响结论。

## 4. 预裁决与一行翻转（已预置）

两台主机的预裁决均为 **`none`**（依据：§2/§3 架构事实 + 各自机器
故事）。翻转行已以注释形式**预置**在主机文件中，裁决被真机证据确认
后即为一行数据变更：

```nix
# hosts/vm/shared.nix · hosts/nixos-wsl/shared.nix
sound = shared.enum.sound.none;
```

翻转是数据，不是文件重写——控制台主机声明不同的行，整栈（pipewire +
wireplumber + rtkit + ALSA 持久化 + pamixer/pavucontrol 工具带）整体
减除（`nixos_core_base_sound_gate` 的 none 形整体减除律已锁定该路径）。

## 5. `just sound-audit` — 机械证据采集

`sound-audit`（hardware 组，只读）按**运行时事实**探测所在机器的形态
——不是 hostname，也不是策略声明（动词层的 T4.0 定律：读已解析的机器，
不读声明）：

- `/proc/sys/kernel/osrelease` 含 `microsoft` → WSL 形态（§3 探针）
- `systemd-detect-virt -v`（缺失时回退 `/proc/cpuinfo` hypervisor 旗标）
  → 虚拟客机形态（§2 探针）
- 其余 → 裸金属形态：无待裁决项，工作站默认（`pipewire`）成立

动词只采集并打印匹配的矩阵行与建议翻转——**不改任何文件**。

## 6. 翻转后验证清单

```bash
# 值面探针（三个 toplevel——已知边界 #10：drv 哈希追踪源树，值面才是等价面）
nix eval --raw .#nixosConfigurations.vm.config.services.pipewire.enable        # 期望 false
nix eval --raw .#nixosConfigurations.nixos-wsl.config.services.pipewire.enable # 期望 false
nix eval --raw .#nixosConfigurations.nixos.config.services.pipewire.enable     # 期望 true（不变）

# 门测试（两形双律在树内已被锁定；翻转后 CI 侧自动复验）
nix build .#api.checks.planes.nixos --no-link   # 含 nixos_core_base_sound_gate
```

推入后 CI 的 deep-eval / host-toplevels / vm-tests 腿按面分片形态自动
复验（T15.1）；`sound_gate` 测试本身与翻转正交（pipewire 形与 none 形
双律都已在断言里）。

## 7. 来源

- microsoft/wslg README（System Distro / WSLGd / Pulse Audio Plugin 三节）：
  system distro 承载 PulseAudio、socket 投影、`PULSE_SERVER` 预配置、
  RDP 通道音频往返
- Windows Command Line 官方博客「WSLg Architecture」（2021-04）：音频
  选型 PulseAudio server + sink/source 插件
- Red Hat Bugzilla #1140937 + 社区实践：libvirt/virt-manager 域默认
  `ich9-intel-hda` 音频设备；裸 QEMU CLI 不默认挂音频设备
- 本仓：`hosts/vm/facter.json`（无音频设备声明）、
  `tests/nixos/core/base/sound-gate.nix`（双律）、
  `lib/shared/lang/enum.nix` sound 行（none 行的契约注释）
