# NixOS 测试完全手册

本手册整合了 NixOS 官方测试文档与实战经验，从基础概念到高级调试，完整覆盖编写、运行、容器化、数据提取、选项参考、常见错误与最佳实践。所有示例均可在真实 Nix 环境中复现。

---

## 目录

1. [NixOS 测试简介](#1-nixos-测试简介)
2. [核心概念与结构](#2-核心概念与结构)
   - 2.1 测试模块的组成
   - 2.2 `nodes`：虚拟机配置
   - 2.3 `testScript`：测试脚本（同步执行模型）
   - 2.4 完整 Machine API 速查表
3. [第一个测试：Hello, World](#3-第一个测试hello-world)
   - 3.1 最简测试模块
   - 3.2 使用 `runNixOSTest` 高阶函数
   - 3.3 使用 `runTest` 低阶函数时的注意事项
4. [运行测试的多种方式](#4-运行测试的多种方式)
   - 4.1 在 Nixpkgs 内运行
   - 4.2 独立运行单个文件
   - 4.3 集成到 Flake 的 `checks`
   - 4.4 独立测试 Flake（推荐）
   - 4.5 交互式运行
5. [深入理解：空配置中的基准系统](#5-深入理解空配置中的基准系统)
6. [容器化测试：`systemd-nspawn` 提速](#6-容器化测试systemd-nspawn-提速)
   - 6.1 基本用法
   - 6.2 宿主机配置
7. [测试集管理与自动扫描](#7-测试集管理与自动扫描)
8. [精确获取虚拟机数据和资源](#8-精确获取虚拟机数据和资源)
   - 8.1 同步执行保证
   - 8.2 命令返回值 vs 截图 vs 控制台日志
   - 8.3 图形屏幕与串口控制台的区别
   - 8.4 实战示例与修正
9. [调试与高级技巧](#9-调试与高级技巧)
   - 9.1 使用 `print` 与 `screenshot`
   - 9.2 交互式调试与 `test_script()`
   - 9.3 沙箱内的 SSH 后门
   - 9.4 失败早期检测：`polling_condition`
   - 9.5 重用虚拟机状态
10. [常见错误与解决方案](#10-常见错误与解决方案)
11. [测试选项完整参考](#11-测试选项完整参考)
12. [向测试传递外部参数（Flake inputs 等）](#12-向测试传递外部参数flake-inputs-等)
13. [覆盖测试与链接包](#13-覆盖测试与链接包)
    - 13.1 `extendNixOS` / `extend`
    - 13.2 `overrideTestDerivation`
    - 13.3 `passthru.tests` 集成
14. [性能优化建议](#14-性能优化建议)
15. [总结与进阶路线](#15-总结与进阶路线)
16. [附录：完整示例与官方资源](#16-附录完整示例与官方资源)

---

## 1. NixOS 测试简介

NixOS 测试框架允许你在**隔离的虚拟机或容器**中验证整个系统行为。它能捕获服务启动失败、依赖缺失、配置错误等回归问题，并作为可执行的文档展示配置预期效果。

---

## 2. 核心概念与结构

### 2.1 测试模块的组成

一个 NixOS 测试是一个 Nix 模块，必须包含 `nodes`（或 `containers`）和 `testScript`。常用属性有：

```nix
{
  name = "my-test";          # 可选（runNixOSTest 自动生成）
  nodes = { ... };           # 或 containers
  testScript = ''...'';

  # 可选选项
  enableOCR = false;
  globalTimeout = 3600;
  extraPythonPackages = p: [ p.numpy ];
  skipLint = false;
  skipTypeCheck = false;
  enableDebugHook = false;
  meta = { ... };
  defaults = { ... };        # 应用到所有节点的 NixOS 配置
  extraBaseModules = { ... }; # 同上，但不可被 specialisation 覆盖
  interactive = { ... };     # 交互模式额外配置
  sshBackdoor = { enable = false; vsockOffset = 2; };
}
```

### 2.2 `nodes`：虚拟机配置

- `nodes.<machine>` 是标准 NixOS 模块，包含服务、用户、文件系统等定义。
- 测试专用的特殊选项：
  - `virtualisation.memorySize`：内存大小（MiB）
  - `virtualisation.vlans`：虚拟网络（参见 `nat.nix` 示例）
  - `virtualisation.writableStore = true`：允许在 VM 中修改 Nix store
  - `virtualisation.useHostStore = true`：直接挂载宿主机 `/nix/store`，加速启动
  - `testing.initrdBackdoor = true` 配合 `boot.initrd.systemd.enable = true` 允许 `machine.switch_root()` 从 stage1 切换到 stage2
- 空配置 `{}` 自动加载一个最小可复现的 NixOS 系统。

### 2.3 `testScript`：测试脚本（同步执行模型）

- 使用 **Python 3** 编写，每个节点对应一个 Python 对象（名字与 `nodes` 中相同）。
- 所有机器方法（如 `succeed`, `wait_for_unit`）都是**同步阻塞**的，即脚本会等待命令/条件完成才继续。因此你完全可以信任 `machine.succeed("echo hello")` 在下一行代码执行时已经完成了。
- 支持 `unittest` 断言：`assert`、`t.assertIn(...)` 等。还提供 `subtest` 上下文管理器分组输出。

### 2.4 完整 Machine API 速查表

| 方法                                                                    | 功能                                      | 关键参数/返回值             |
| ----------------------------------------------------------------------- | ----------------------------------------- | --------------------------- |
| **生命周期**                                                            |                                           |                             |
| `start(allow_reboot=False)`                                             | 启动 VM（异步）                           |                             |
| `shutdown()`                                                            | 优雅关机                                  |                             |
| `crash()`                                                               | 模拟断电                                  |                             |
| `reboot()`                                                              | 发送 Ctrl+Alt+Del，需 `allow_reboot=True` | 仅 QEMU                     |
| `switch_root()`                                                         | 从 stage1 切到 stage2                     | 需 `testing.initrdBackdoor` |
| **命令执行**                                                            |                                           |                             |
| `succeed(cmd)`                                                          | 执行命令，失败抛异常                      | 返回 stdout，默认超时 None  |
| `fail(cmd)`                                                             | 执行命令，期待失败（返回非零）            |                             |
| `execute(cmd, check_return=True, timeout=900)`                          | 返回 `(status, stdout)`                   | 可忽略返回码、设定超时      |
| `wait_until_succeeds(cmd, timeout=900)`                                 | 重试直到成功                              | 间隔 1 秒                   |
| `wait_until_fails(cmd, timeout=900)`                                    | 重试直到失败                              |                             |
| `systemctl(query, user=None)`                                           | 运行 systemctl 命令                       | 返回输出                    |
| **等待条件**                                                            |                                           |                             |
| `wait_for_unit(unit, user=None, timeout)`                               | 等待 systemd 单元进入 active              |                             |
| `wait_for_file(filename, timeout)`                                      | 等待文件出现                              |                             |
| `wait_for_open_port(port, addr, timeout)` / `wait_for_closed_port(...)` | 等待端口监听/关闭                         |                             |
| `wait_for_open_unix_socket(addr, is_datagram=False, timeout)`           | 等待 Unix socket                          |                             |
| `wait_for_console_text(regex, timeout)`                                 | 等待串口日志出现匹配文本                  |                             |
| `wait_for_text(regex, timeout)`                                         | 通过 OCR 等待屏幕文字                     | 需 `enableOCR = true`       |
| `wait_for_window(regex, timeout)`                                       | 等待 X11 窗口出现                         |                             |
| `wait_for_x(timeout)`                                                   | 等待 X 服务器可用                         |                             |
| `wait_until_tty_matches(tty, regex, timeout)`                           | 等待某 TTY 可见内容匹配                   |                             |
| **交互与控制**                                                          |                                           |                             |
| `send_key(key, delay=None)`                                             | 发送按键，如 `"ctrl-alt-delete"`          |                             |
| `send_chars(chars, delay=None)`                                         | 逐字符输入字符串                          |                             |
| `send_console(chars)`                                                   | 向内核控制台发字符串（emergency 模式）    |                             |
| `send_monitor_command(cmd)`                                             | 发命令到 QEMU monitor                     |                             |
| `block()` / `unblock()`                                                 | 模拟拔/插 eth1 网线                       |                             |
| `forward_port(host_port, guest_port)`                                   | 在交互测试中转发 TCP 端口                 |                             |
| **信息获取**                                                            |                                           |                             |
| `screenshot(filename)`                                                  | 保存图形屏幕的 PNG 截图到 derivation 输出 |                             |
| `get_console_log()`                                                     | 返回所有串口输出字符串                    |                             |
| `get_screen_text()` / `get_screen_text_variants()`                      | OCR 识别屏幕文本（需 `enableOCR`）        |                             |
| `dump_tty_contents(tty)`                                                | 转储 TTY 当前内容（调试用）               |                             |
| `copy_from_host(src, dst)`                                              | 从构建沙箱拷贝文件到 VM                   |                             |
| `copy_from_host_via_shell(src, dst)`                                    | 通过 shell 管道拷贝，无共享目录           |                             |
| `copy_from_vm(src, target_dir)`                                         | 从 VM 拷贝文件到 `$out` 下                |                             |
| **调试专用**                                                            |                                           |                             |
| `console_interact()`                                                    | 直接与 QEMU stdin 交互（仅交互测试）      |                             |
| `shell_interact(address=None)`                                          | 获得 VM 内 shell，可接 TCP 地址           |                             |
| `_managed_screenshot()`                                                 | 截图并返回路径（生成器）                  |                             |

更多方法见官方手册或 `nixos/lib/test-driver.py`。

---

## 3. 第一个测试：Hello, World

### 3.1 最简测试模块

`tests/hello.nix`:

```nix
{
  nodes.machine = {};

  testScript = ''
    start_all()
    output = machine.succeed("echo 'hello, world!'")
    assert output.strip() == "hello, world!"
  '';
}
```

### 3.2 使用 `runNixOSTest` 高阶函数（推荐）

```nix
# flake.nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
  in {
    checks.x86_64-linux.hello = pkgs.testers.runNixOSTest (import ./tests/hello.nix);
  };
}
```

`runNixOSTest` 自动处理 `name`、`hostPkgs` 等胶水代码，无需在测试文件中显式声明。

### 3.3 使用 `runTest` 低阶函数时的注意事项

如果直接使用 `lib.nixos.runTest`，需手动提供 `hostPkgs` 和 `name`：

```nix
nixpkgs.lib.nixos.runTest {
  hostPkgs = pkgs;
  name = "my-test";
  imports = [ ./test-module.nix ];
}
```

但多数情况下推荐用 `runNixOSTest` 避免遗漏。

---

## 4. 运行测试的多种方式

### 4.1 在 Nixpkgs 内运行

若测试在 `nixpkgs/nixos/tests/` 下且注册于 `all-tests.nix`：

```bash
cd nixpkgs
nix-build -A nixosTests.<test-name>
```

### 4.2 独立运行单个文件

```bash
nix-build -E '(import <nixpkgs/nixos/tests/make-test-python.nix> (import ./test.nix)).test'
```

依赖 channel，不推荐。

### 4.3 集成到 Flake 的 `checks`

```nix
checks.x86_64-linux.my-test = pkgs.testers.runNixOSTest (import ./my-test.nix);
```

运行：

```bash
nix flake check                         # 所有测试
nix build .#checks.x86_64-linux.my-test -L  # -L 打印详细输出
```

### 4.4 独立测试 Flake（推荐）

在 `tests/` 目录下创建独立的 `flake.nix`，使测试与主配置解耦，并可自动扫描所有测试文件。

### 4.5 交互式运行

```bash
nix build .#checks.x86_64-linux.my-test.driverInteractive
./result/bin/nixos-test-driver
```

进入 Python REPL，可单步执行 `start_all()`, `machine.succeed(...)` 等。执行 `test_script()` 可运行整个测试脚本并保留环境。

---

## 5. 深入理解：空配置中的基准系统

`nodes.machine = {}` 实际加载：

- `nixos/modules/virtualisation/qemu-vm.nix`：磁盘、网络、QEMU 参数
- `nixos/modules/profiles/minimal.nix`：禁用非必要服务，保留 systemd、bash、coreutils 等
- 默认内核包和 initrd

因此测试环境是**完全可复现的最小 NixOS**，不受宿主机影响。

---

## 6. 容器化测试：`systemd-nspawn` 提速

### 6.1 基本用法

```nix
{
  containers.machine = { services.nginx.enable = true; };
  testScript = ''
    start_all()
    machine.wait_for_unit("nginx.service")
    assert "Welcome" in machine.succeed("curl http://localhost")
  '';
}
```

- 优势：启动 2~5 秒，内存 ~200MB
- 限制：共享宿主机内核，不支持 `reboot()`；需要宿主支持用户名字空间

### 6.2 宿主机配置

在 NixOS 宿主机上启用：

```nix
nix.settings = {
  auto-allocate-uids = true;
  experimental-features = [ "auto-allocate-uids" "cgroups" ];
  extra-system-features = [ "uid-range" ];
};
```

非 NixOS 宿主建议使用 QEMU 模式。

---

## 7. 测试集管理与自动扫描

```
tests/
├── flake.nix
├── hello.nix
├── sops.nix
└── databases/
    ├── postgresql.nix
    └── mysql.nix
```

在 `tests/flake.nix` 中自动扫描所有 `.nix` 文件：

```nix
{
  outputs = { nixpkgs, ... }: let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    scanTests = dir: let
      files = builtins.attrNames (builtins.readDir dir);
      nixFiles = builtins.filter (f: builtins.hasSuffix ".nix" f) files;
    in builtins.listToAttrs (map (f: {
      name = builtins.replaceStrings [ ".nix" ] [ "" ] f;
      value = pkgs.testers.runNixOSTest (import (dir + "/${f}"));
    }) nixFiles);
  in { checks.x86_64-linux = scanTests ./.; };
}
```

---

## 8. 精确获取虚拟机数据和资源

### 8.1 同步执行保证

所有机器方法都是同步的。例如 `machine.succeed("echo hello")` 会阻塞直到命令完成并返回 stdout，因此后续代码直接使用返回值即可，无需等待或添加延迟。

### 8.2 命令返回值 vs 截图 vs 控制台日志

| 数据来源    | 获取方法                        | 精确度                 | 推荐场景         |
| ----------- | ------------------------------- | ---------------------- | ---------------- |
| 命令 stdout | `output = machine.succeed(cmd)` | **最高**               | 断言命令输出     |
| 串口日志    | `machine.get_console_log()`     | 中（全日志混合）       | 辅助调试         |
| 图形屏幕    | `machine.screenshot(filename)`  | 低（只能看图形内容）   | GUI 验证         |
| OCR 文本    | `machine.get_screen_text()`     | 低（依赖 `enableOCR`） | 图形界面文字验证 |

**核心原则**：能用 `succeed()` 返回值，绝不依赖截图或日志搜索。

### 8.3 图形屏幕与串口控制台的区别

- **串口控制台 (ttyS0)**：所有内核/systemd 日志，`succeed` 执行的命令输出都在这里。
- **图形屏幕 (tty1~tty7)**：VGA 帧缓冲，通常只显示登录提示或 GUI。`echo` 命令输出不显示在此。

因此，**截图无法捕获 `succeed()` 中命令的输出**。若需在截图中看到命令输出，必须将输出发送到图形终端（如 tty2），并使用 `send_chars` 模拟输入，不推荐用于验证输出内容。

### 8.4 实战示例与修正

❌ 错误：

```python
machine.succeed("echo 'hello'")
machine.screenshot("after-echo")  # 截图中看不到
```

✅ 正确：

```python
output = machine.succeed("echo 'hello'")
assert output.strip() == "hello"
print(f"验证输出: {output.strip()}")   # 日志中可见
```

✅ 若一定要在图形终端看到（仅演示）：

```python
machine.send_key("alt-f2")
machine.wait_for_unit("getty@tty2.service")
machine.wait_until_tty_matches("2", "login: ")
machine.send_chars("root\n")                # 需 root 免密或自动登录
machine.wait_until_tty_matches("2", "root@")
machine.send_chars("echo 'hello'\n")
machine.screenshot("tty2-hello")
```

---

## 9. 调试与高级技巧

### 9.1 使用 `print` 与 `screenshot`

- `print()` 输出出现在 `nix build -L` 的日志中，也可用 `nix log` 查看。
- `screenshot` 的 PNG 位于输出目录的 `screenshots/` 下，路径在构建日志中会打印。

### 9.2 交互式调试与 `test_script()`

交互式驱动（`driverInteractive`）启动后，可在 REPL 中调用 `machine.start()`、`machine.succeed("...")` 等。调用 `test_script()` 可执行完整测试脚本，执行完毕后仍可继续检查状态。

### 9.3 沙箱内的 SSH 后门

在测试模块中设置：

```nix
{
  enableDebugHook = true;
  sshBackdoor.enable = true;
}
```

构建时传递 `/dev/vhost-vsock`：

```bash
nix-build -A nixosTests.foo --option sandbox-paths /dev/vhost-vsock
```

失败后按提示进入 sandbox，使用 `ssh -F ./ssh_config vsock/3` 登录 VM（节点编号从 3 开始）。若同时运行多个测试可能冲突，可设置 `sshBackdoor.vsockOffset`。

### 9.4 失败早期检测：`polling_condition`

```python
@polling_condition(seconds_interval=10, description="检查 nginx 存活")
def nginx_running():
    machine.succeed("pgrep nginx")

with nginx_running:
    # 此段代码执行期间若 nginx 退出，测试立即失败
    machine.succeed("stress --cpu 1 &")
```

### 9.5 重用虚拟机状态

```bash
./result/bin/nixos-test-driver --keep-vm-state
```

状态保存在 `$TMPDIR/vm-state-machinename`，便于反复调试。

---

## 10. 常见错误与解决方案

| 错误现象                                                   | 原因                                                    | 解决                                                               |
| ---------------------------------------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------ |
| `option 'name' has no value`                               | 使用低阶 `runTest` 未定义 `name`                        | 添加 `name` 或用 `runNixOSTest`                                    |
| `option 'hostPkgs' has no value`                           | 直接调用 `lib.nixos.runTest`                            | 提供 `hostPkgs` 或用 `runNixOSTest`                                |
| `The option 'specialArgs' does not exist`                  | 在 `runNixOSTest` 顶层使用了不存在的 `specialArgs` 选项 | 改用 `_module.args` 传递参数（见第12节）                           |
| `attribute 'inputs' missing` 或依赖的外部 Flake 输入不可用 | 测试模块期望 `inputs` 参数但未被注入                    | 通过 `_module.args = { inherit inputs; }` 注入（见第12节）         |
| 测试中 `machine` 未定义                                    | 节点名不是 `machine`                                    | 保持名称一致，如 `nodes.myNode` 用 `myNode`                        |
| 截图显示 “Guest has not initialized the display (yet)”     | 图形驱动未初始化就截图                                  | 在 `wait_for_unit("multi-user.target")` 或 `wait_for_x()` 之后截图 |
| 命令输出在截图中看不到                                     | 截图是图形屏幕，命令输出在串口                          | 用 `succeed()` 返回值；如需图形终端输出参考 8.4                    |
| `wait_for_console_text` 超时                               | 在命令执行前等待，或正则不匹配                          | 确保已执行产生该文本的命令；或用 `succeed` 返回值代替              |
| 容器模式 `reboot()` 失败                                   | 容器共享内核                                            | 用 `crash() + start()` 模拟，或改用 QEMU                           |
| VSOCK 地址冲突 (`Address already in use`)                  | 多个测试同时启用 SSH 后门                               | 设置 `sshBackdoor.vsockOffset = 23542` 等                          |
| OCR 识别不准确或截图模糊                                   | 屏幕分辨率/字体影响                                     | 增加 `sleep`，或改用 `wait_for_console_text`                       |
| 测试通过但无任何输出打印                                   | `nix flake check` 默认只打印失败日志                    | 使用 `nix build -L`，或 `nix log` 查看完整日志                     |
| 测试超时                                                   | 默认全局超时 3600 秒可能不合适                          | 设置 `globalTimeout` 或命令级 `timeout` 参数                       |

---

## 11. 测试选项完整参考

除 `nodes` 和 `testScript` 外，测试模块还支持以下常用选项：

| 选项                      | 类型         | 默认值               | 说明                                                     |
| ------------------------- | ------------ | -------------------- | -------------------------------------------------------- |
| `name`                    | string       | 自动生成             | 测试名称，影响 derivation 命名                           |
| `globalTimeout`           | int          | 3600                 | 全局超时（秒）                                           |
| `enableOCR`               | bool         | false                | 启用光学字符识别                                         |
| `extraPythonPackages`     | function     | `_ : []`             | 如 `p: [ p.numpy ]`（需同时设 `skipTypeCheck=true`）     |
| `skipLint`                | bool         | false                | 跳过 Black 格式检查（调试用，勿提交）                    |
| `skipTypeCheck`           | bool         | false                | 跳过类型检查                                             |
| `enableDebugHook`         | bool         | false                | 失败时暂停并提供调试接口                                 |
| `interactive`             | submodule    | `{}`                 | 交互模式下的额外配置（如开启图形）                       |
| `defaults`                | NixOS module | `{}`                 | 应用到所有节点的配置                                     |
| `extraBaseModules`        | NixOS module | `{}`                 | 同 defaults，但不可被 specialisation 覆盖                |
| `meta`                    | attr set     | `{}`                 | 可设置 `broken`, `maintainers`, `platforms`, `timeout`   |
| `qemu.package`            | package      | `hostPkgs.qemu_test` | 使用的 QEMU 包                                           |
| `sshBackdoor.enable`      | bool         | false                | 启用 VSOCK SSH 后门                                      |
| `sshBackdoor.vsockOffset` | int          | 2                    | 避免 VSOCK 地址冲突                                      |
| `node.pkgs`               | pkgs         | null                 | 节点使用的 nixpkgs 实例                                  |
| `node.specialArgs`        | attr set     | `{}`                 | **传递给节点模块**的额外参数（注意：不是传递给测试模块） |
| `passthru`                | attr set     | `{}`                 | 附加到最终 derivation 的属性                             |
| `hostPkgs`                | pkgs         | 自动                 | 宿主机侧使用的 nixpkgs                                   |

完整列表见 `nixos/lib/testing/*.nix`。

---

## 12. 向测试传递外部参数（Flake inputs 等）

大多数非平凡测试都需要从外部引入配置，例如 `inputs.home-manager`、`inputs.sops-nix` 等。测试模块可以通过参数 `inputs`、`pkgs`、`lib` 等方式接收这些值，但 `runNixOSTest` 默认只传递 `pkgs`、`lib` 等基础参数。若需要额外的参数，**必须使用 `_module.args` 进行注入**，而不能使用 `specialArgs`（因为测试模块没有 `specialArgs` 这个选项）。

### 12.1 推荐做法：在 `runNixOSTest` 中设置 `_module.args`

创建一个通用的测试运行器（例如放在 `tests/default.nix`）：

```nix
{ inputs, shared, ... }:
let
  pkgs = shared.pkgs;

  # 推荐的高阶测试运行器：自动注入 inputs 供所有测试模块使用
  nixosTest = path: pkgs.testers.runNixOSTest {
    _module.args = { inherit inputs; };   # 将 flake inputs 传给测试模块
    imports = [ path ];
  };
in
...
```

在 `flake.nix` 的 `checks` 中使用该运行器：

```nix
checks.x86_64-linux.integration-test = nixosTest ./tests/integration/my-test.nix;
```

### 12.2 测试模块一侧的声明

测试模块直接声明同名参数，不再需要默认值：

```nix
{ pkgs, lib, inputs, ... }:
{
  # 现在可以直接使用 inputs.home-manager 等
  nodes.machine = { ... }: {
    imports = [ inputs.home-manager.nixosModules.home-manager ];
    ...
  };
  testScript = ''...'';
}
```

### 12.3 如果只想为某个测试传递特定参数

也可以在单个测试文件中添加 `_module.args`：

```nix
{
  _module.args.myCustomArg = "hello";
  nodes.machine = { ... };
  ...
}
```

**注意**：

- `node.specialArgs` 是测试选项，用于向**节点模块**传递参数，不是向测试模块本身传递。
- 不要在 `runNixOSTest` 的顶层参数中写 `specialArgs`，否则会报错 `option 'specialArgs' does not exist`。

### 12.4 示例：集成 home‑manager 的完整测试

```nix
# tests/integration/hm_activation.nix
{ pkgs, lib, inputs, ... }:
let
  testUser = "hmuser";
in
{
  name = "integration-hm";
  meta.maintainers = [ "yourname" ];

  nodes.machine = { ... }: {
    virtualisation.memorySize = 1536;
    users.users.${testUser} = {
      isNormalUser = true;
      initialPassword = "test";
    };
    imports = [ inputs.home-manager.nixosModules.home-manager ];
    home-manager.users.${testUser} = {
      home.stateVersion = "24.11";
      programs.zsh.enable = true;
      home.packages = [ pkgs.ripgrep ];
    };
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    shell = machine.succeed("getent passwd ${testUser} | cut -d: -f7")
    assert "zsh" in shell
    out = machine.succeed("su - ${testUser} -c 'rg --version'")
    assert "ripgrep" in out
  '';
}
```

在 `flake.nix` 的 checks 中使用前述 `nixosTest` 包装函数即可。

---

## 13. 覆盖测试与链接包

### 13.1 `extendNixOS` / `extend`

在不修改原始测试的情况下，向所有节点注入额外的模块或参数：

```nix
nixosTests.openssh.extendNixOS {
  module = { services.openssh.package = myCustomPkg; };
  specialArgs = { myArg = "value"; };
}
```

也可使用通用的 `extend` 函数添加测试模块。

### 13.2 `overrideTestDerivation`

直接修改测试的 derivation，例如添加额外依赖：

```nix
myTest.overrideTestDerivation (prevAttrs: {
  buildInputs = prevAttrs.buildInputs ++ [ extraPkg ];
})
```

### 13.3 `passthru.tests` 集成

将测试与包链接，在包更新时自动运行：

```nix
stdenv.mkDerivation {
  ...
  passthru.tests.nixos = nixosTests.my-service.extendNixOS {
    module = { services.myService.package = finalAttrs.finalPackage; };
  };
}
```

---

## 14. 性能优化建议

- **容器模式优先**：服务层测试用 `containers`，启动快，内存少。
- **`virtualisation.useHostStore = true`**：QEMU 模式下挂载宿主机 store，避免复制。
- **`virtualisation.memorySize`**：默认 1024 MiB，如测试轻量服务可减小。
- **纯逻辑用 `runCommand`**：不启动虚拟机，直接在构建沙箱执行。
- **缓存与镜像**：使用 `cachix` 或国内镜像加速首次构建；后续构建自动利用 Nix 缓存。

---

## 15. 总结与进阶路线

✅ 通过本手册你已掌握：

- 编写和运行 NixOS 测试模块
- 选用 QEMU 或 systemd-nspawn 容器后端
- 精确提取命令输出、串口日志和截图
- 在 Flake 中集成测试，自动扫描管理
- 调试失败测试：交互式 REPL、SSH 后门、截图、日志
- 避免 `name`/`hostPkgs` 遗漏、容器 reboot、VSOCK 冲突等常见错误
- 向测试模块安全传递外部 Flake 输入（`_module.args`）

📚 下一步建议：

1. 为核心服务（数据库、Web 服务、加密挂载等）编写测试
2. 构建多节点测试（客户端-服务器、故障转移）
3. 在 CI（GitHub Actions）中执行 `nix flake check`，存档截图
4. 为 Nixpkgs 贡献测试，参考 `nixos/tests/` 中的官方示例

---

## 16. 附录：完整示例与官方资源

### 官方测试示例

- **login.nix**：用户登录、VT 切换、设备权限验证
- **nfs/simple.nix**：多节点 NFS 锁、崩溃恢复
- **fcitx5.nix**：输入法图形测试（OCR、窗口匹配）

### 官方文档

- [NixOS Tests 官方手册](https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests)
- [Nixpkgs 测试贡献指南](https://nixos.org/manual/nixpkgs/stable/#sec-testing)

### 综合示例：带 OCR 和 polling_condition 的服务测试

```nix
{ pkgs, ... }: {
  name = "nginx-gui-test";
  meta.maintainers = [ "you" ];
  enableOCR = true;

  nodes.machine = {
    services.nginx.enable = true;
    services.xserver.enable = true;
    services.xserver.displayManager.autoLogin.enable = true;
    services.xserver.displayManager.autoLogin.user = "test";
    environment.systemPackages = [ pkgs.firefox ];
  };

  testScript = ''
    start_all()
    machine.wait_for_x()
    machine.wait_for_unit("nginx.service")

    with subtest("打开浏览器验证标题"):
        machine.succeed("firefox http://localhost &")
        machine.wait_for_window("Firefox")
        machine.wait_for_text("Welcome to nginx")
        machine.screenshot("browser-nginx")

    @polling_condition(seconds_interval=5)
    def nginx_still_running():
        machine.succeed("pgrep nginx")

    with nginx_still_running:
        machine.succeed("sleep 10")
  '';
}
```

---
