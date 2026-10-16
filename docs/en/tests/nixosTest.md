# The Complete NixOS Testing Handbook

> English mirror of [docs/tests/nixosTest.md](../../tests/nixosTest.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

This handbook consolidates the official NixOS test documentation with hands-on experience. From basic concepts to advanced debugging, it fully covers writing, running, containerization, data extraction, option references, common errors, and best practices. Every example is reproducible in a real Nix environment.

---

## Table of Contents

1. [Introduction to NixOS Tests](#1-introduction-to-nixos-tests)
2. [Core Concepts and Structure](#2-core-concepts-and-structure)
   - 2.1 Anatomy of a Test Module
   - 2.2 `nodes`: Virtual-Machine Configurations
   - 2.3 `testScript`: The Test Script (Synchronous Execution Model)
   - 2.4 The Complete Machine API Quick Reference
3. [Your First Test: Hello, World](#3-your-first-test-hello-world)
   - 3.1 The Minimal Test Module
   - 3.2 Using the `runNixOSTest` Higher-Order Function
   - 3.3 Caveats When Using the Low-Level `runTest` Function
4. [The Many Ways to Run Tests](#4-the-many-ways-to-run-tests)
   - 4.1 Running Inside Nixpkgs
   - 4.2 Running a Single File Standalone
   - 4.3 Integrating into a Flake's `checks`
   - 4.4 A Standalone Test Flake (Recommended)
   - 4.5 Running Interactively
5. [Deep Dive: The Baseline System Inside an Empty Configuration](#5-deep-dive-the-baseline-system-inside-an-empty-configuration)
6. [Containerized Testing: `systemd-nspawn` Speedup](#6-containerized-testing-systemd-nspawn-speedup)
   - 6.1 Basic Usage
   - 6.2 Host Configuration
7. [Test-Suite Management and Automatic Scanning](#7-test-suite-management-and-automatic-scanning)
8. [Extracting Virtual-Machine Data and Resources Precisely](#8-extracting-virtual-machine-data-and-resources-precisely)
   - 8.1 The Synchronous-Execution Guarantee
   - 8.2 Command Return Values vs Screenshots vs Console Logs
   - 8.3 The Difference Between the Graphical Screen and the Serial Console
   - 8.4 Hands-On Examples and Corrections
9. [Debugging and Advanced Techniques](#9-debugging-and-advanced-techniques)
   - 9.1 Using `print` and `screenshot`
   - 9.2 Interactive Debugging and `test_script()`
   - 9.3 The SSH Backdoor Inside the Sandbox
   - 9.4 Early Failure Detection: `polling_condition`
   - 9.5 Reusing Virtual-Machine State
10. [Common Errors and Solutions](#10-common-errors-and-solutions)
11. [The Complete Test-Option Reference](#11-the-complete-test-option-reference)
12. [Passing External Arguments to Tests (Flake Inputs, etc.)](#12-passing-external-arguments-to-tests-flake-inputs-etc)
13. [Overriding Tests and Linked Packages](#13-overriding-tests-and-linked-packages)
    - 13.1 `extendNixOS` / `extend`
    - 13.2 `overrideTestDerivation`
    - 13.3 `passthru.tests` Integration
14. [Performance-Optimization Tips](#14-performance-optimization-tips)
15. [Summary and the Road Ahead](#15-summary-and-the-road-ahead)
16. [Appendix: Complete Examples and Official Resources](#16-appendix-complete-examples-and-official-resources)

---

## 1. Introduction to NixOS Tests

The NixOS test framework lets you verify whole-system behavior in **isolated virtual machines or containers**. It catches regressions such as failing service startups, missing dependencies, or misconfiguration, and doubles as executable documentation of what the configuration is expected to do.

---

## 2. Core Concepts and Structure

### 2.1 Anatomy of a Test Module

A NixOS test is a Nix module that must contain `nodes` (or `containers`) and `testScript`. Commonly used attributes:

```nix
{
  name = "my-test";          # optional (runNixOSTest generates it automatically)
  nodes = { ... };           # or containers
  testScript = ''...'';

  # optional options
  enableOCR = false;
  globalTimeout = 3600;
  extraPythonPackages = p: [ p.numpy ];
  skipLint = false;
  skipTypeCheck = false;
  enableDebugHook = false;
  meta = { ... };
  defaults = { ... };        # NixOS configuration applied to all nodes
  extraBaseModules = { ... }; # same as above, but cannot be overridden by specialisation
  interactive = { ... };     # extra configuration for interactive mode
  sshBackdoor = { enable = false; vsockOffset = 2; };
}
```

### 2.2 `nodes`: Virtual-Machine Configurations

- `nodes.<machine>` is a standard NixOS module, containing services, users, file systems, and other definitions.
- Special options dedicated to testing:
  - `virtualisation.memorySize`: memory size (MiB)
  - `virtualisation.vlans`: virtual networks (see the `nat.nix` example)
  - `virtualisation.writableStore = true`: allows modifying the Nix store inside the VM
  - `virtualisation.useHostStore = true`: mounts the host's `/nix/store` directly, speeding up boot
  - `testing.initrdBackdoor = true` together with `boot.initrd.systemd.enable = true` allows `machine.switch_root()` to switch from stage1 to stage2
- The empty configuration `{}` automatically loads a minimal, reproducible NixOS system.

### 2.3 `testScript`: The Test Script (Synchronous Execution Model)

- Written in **Python 3**; each node maps to a Python object (named the same as in `nodes`).
- All machine methods (e.g. `succeed`, `wait_for_unit`) are **synchronous and blocking** — the script waits for the command/condition to complete before continuing. You can therefore fully trust that `machine.succeed("echo hello")` has already finished by the time the next line runs.
- `unittest`-style assertions are supported: `assert`, `t.assertIn(...)`, etc. A `subtest` context manager is also provided to group output.

### 2.4 The Complete Machine API Quick Reference

| Method                                                                   | What it does                            | Key parameters/return value |
| ------------------------------------------------------------------------ | --------------------------------------- | --------------------------- |
| **Lifecycle**                                                            |                                         |                             |
| `start(allow_reboot=False)`                                              | Starts the VM (asynchronous)            |                             |
| `shutdown()`                                                             | Graceful shutdown                       |                             |
| `crash()`                                                                | Simulates a power loss                  |                             |
| `reboot()`                                                               | Sends Ctrl+Alt+Del; needs `allow_reboot=True` | QEMU only             |
| `switch_root()`                                                          | Switches from stage1 to stage2           | needs `testing.initrdBackdoor` |
| **Command execution**                                                    |                                         |                             |
| `succeed(cmd)`                                                           | Runs the command, throws on failure     | returns stdout; default timeout None |
| `fail(cmd)`                                                              | Runs the command, expecting failure (non-zero return) |                   |
| `execute(cmd, check_return=True, timeout=900)`                           | Returns `(status, stdout)`               | can ignore the return code, set a timeout |
| `wait_until_succeeds(cmd, timeout=900)`                                  | Retries until it succeeds               | 1-second interval           |
| `wait_until_fails(cmd, timeout=900)`                                     | Retries until it fails                  |                             |
| `systemctl(query, user=None)`                                            | Runs a systemctl command                | returns the output          |
| **Wait conditions**                                                      |                                         |                             |
| `wait_for_unit(unit, user=None, timeout)`                                | Waits for a systemd unit to become active |                           |
| `wait_for_file(filename, timeout)`                                       | Waits for a file to appear              |                             |
| `wait_for_open_port(port, addr, timeout)` / `wait_for_closed_port(...)`  | Waits for a port to be listening/closed |                             |
| `wait_for_open_unix_socket(addr, is_datagram=False, timeout)`            | Waits for a Unix socket                 |                             |
| `wait_for_console_text(regex, timeout)`                                  | Waits for matching text in the serial log |                           |
| `wait_for_text(regex, timeout)`                                          | Waits for on-screen text via OCR         | needs `enableOCR = true`    |
| `wait_for_window(regex, timeout)`                                        | Waits for an X11 window to appear       |                             |
| `wait_for_x(timeout)`                                                     | Waits for the X server to be available  |                             |
| `wait_until_tty_matches(tty, regex, timeout)`                            | Waits until a TTY's visible content matches |                         |
| **Interaction and control**                                              |                                         |                             |
| `send_key(key, delay=None)`                                              | Sends a key press, e.g. `"ctrl-alt-delete"` |                        |
| `send_chars(chars, delay=None)`                                          | Types a string character by character    |                             |
| `send_console(chars)`                                                    | Sends a string to the kernel console (emergency mode) |              |
| `send_monitor_command(cmd)`                                              | Sends a command to the QEMU monitor     |                             |
| `block()` / `unblock()`                                                  | Simulates unplugging/plugging the eth1 cable |                      |
| `forward_port(host_port, guest_port)`                                    | Forwards a TCP port in interactive tests |                            |
| **Information retrieval**                                                |                                         |                             |
| `screenshot(filename)`                                                   | Saves a PNG screenshot of the graphical screen to the derivation output |          |
| `get_console_log()`                                                      | Returns all serial output as a string   |                             |
| `get_screen_text()` / `get_screen_text_variants()`                       | OCR-recognizes on-screen text (needs `enableOCR`) |                   |
| `dump_tty_contents(tty)`                                                 | Dumps the current TTY contents (for debugging) |                      |
| `copy_from_host(src, dst)`                                               | Copies a file from the build sandbox into the VM |                  |
| `copy_from_host_via_shell(src, dst)`                                     | Copies via a shell pipe; no shared directory |                     |
| `copy_from_vm(src, target_dir)`                                           | Copies files out of the VM under `$out` |                             |
| **Debugging only**                                                       |                                         |                             |
| `console_interact()`                                                     | Interacts directly with QEMU stdin (interactive tests only) |       |
| `shell_interact(address=None)`                                           | Gets a shell inside the VM; can take a TCP address |                |
| `_managed_screenshot()`                                                 | Takes a screenshot and returns the path (a generator) |             |

See the official manual or `nixos/lib/test-driver.py` for more methods.

---

## 3. Your First Test: Hello, World

### 3.1 The Minimal Test Module

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

### 3.2 Using the `runNixOSTest` Higher-Order Function (Recommended)

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

`runNixOSTest` handles the `name`, `hostPkgs`, and similar glue automatically — no need to declare it explicitly in the test file.

### 3.3 Caveats When Using the Low-Level `runTest` Function

If you use `lib.nixos.runTest` directly, you must provide `hostPkgs` and `name` yourself:

```nix
nixpkgs.lib.nixos.runTest {
  hostPkgs = pkgs;
  name = "my-test";
  imports = [ ./test-module.nix ];
}
```

In most cases, though, prefer `runNixOSTest` to avoid omissions.

---

## 4. The Many Ways to Run Tests

### 4.1 Running Inside Nixpkgs

If the test lives under `nixpkgs/nixos/tests/` and is registered in `all-tests.nix`:

```bash
cd nixpkgs
nix-build -A nixosTests.<test-name>
```

### 4.2 Running a Single File Standalone

```bash
nix-build -E '(import <nixpkgs/nixos/tests/make-test-python.nix> (import ./test.nix)).test'
```

Depends on the channel; not recommended.

### 4.3 Integrating into a Flake's `checks`

```nix
checks.x86_64-linux.my-test = pkgs.testers.runNixOSTest (import ./my-test.nix);
```

Run:

```bash
nix flake check                         # all tests
nix build .#checks.x86_64-linux.my-test -L  # -L prints verbose output
```

### 4.4 A Standalone Test Flake (Recommended)

Create a separate `flake.nix` under `tests/`, decoupling the tests from the main configuration and enabling automatic scanning of all test files.

### 4.5 Running Interactively

```bash
nix build .#checks.x86_64-linux.my-test.driverInteractive
./result/bin/nixos-test-driver
```

This drops you into a Python REPL where you can execute `start_all()`, `machine.succeed(...)`, and so on step by step. Running `test_script()` executes the entire test script while keeping the environment.

---

## 5. Deep Dive: The Baseline System Inside an Empty Configuration

`nodes.machine = {}` actually loads:

- `nixos/modules/virtualisation/qemu-vm.nix`: disks, networking, QEMU parameters
- `nixos/modules/profiles/minimal.nix`: disables non-essential services while keeping systemd, bash, coreutils, and friends
- The default kernel package and initrd

The test environment is therefore a **fully reproducible, minimal NixOS**, unaffected by the host.

---

## 6. Containerized Testing: `systemd-nspawn` Speedup

### 6.1 Basic Usage

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

- Advantages: 2~5 s startup, ~200MB memory
- Limitations: shares the host kernel, no `reboot()` support; the host must support user namespaces

### 6.2 Host Configuration

Enable this on the NixOS host:

```nix
nix.settings = {
  auto-allocate-uids = true;
  experimental-features = [ "auto-allocate-uids" "cgroups" ];
  extra-system-features = [ "uid-range" ];
};
```

On non-NixOS hosts, QEMU mode is recommended.

---

## 7. Test-Suite Management and Automatic Scanning

```
tests/
├── flake.nix
├── hello.nix
├── sops.nix
└── databases/
    ├── postgresql.nix
    └── mysql.nix
```

Automatically scan all `.nix` files in `tests/flake.nix`:

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

## 8. Extracting Virtual-Machine Data and Resources Precisely

### 8.1 The Synchronous-Execution Guarantee

All machine methods are synchronous. For example, `machine.succeed("echo hello")` blocks until the command completes and returns stdout, so subsequent code can use the return value directly — no waiting or artificial delays needed.

### 8.2 Command Return Values vs Screenshots vs Console Logs

| Data source       | How to obtain                       | Precision                  | Recommended use           |
| ----------------- | ----------------------------------- | --------------------------- | ------------------------- |
| Command stdout    | `output = machine.succeed(cmd)`     | **Highest**                | Asserting command output  |
| Serial log        | `machine.get_console_log()`         | Medium (the full log, mixed) | Debugging aid           |
| Graphical screen  | `machine.screenshot(filename)`      | Low (graphical content only) | GUI verification        |
| OCR text          | `machine.get_screen_text()`         | Low (depends on `enableOCR`) | Verifying GUI text      |

**Core principle**: if you can use a `succeed()` return value, never rely on screenshots or log searching.

### 8.3 The Difference Between the Graphical Screen and the Serial Console

- **Serial console (ttyS0)**: all kernel/systemd logs, plus the output of commands run by `succeed`, land here.
- **Graphical screen (tty1~tty7)**: the VGA framebuffer; usually shows only a login prompt or a GUI. `echo` output does not appear here.

Therefore, **a screenshot cannot capture the output of commands inside `succeed()`**. If you must see command output in a screenshot, you have to send the output to a graphical terminal (e.g. tty2) and use `send_chars` to simulate typing — not recommended for verifying output content.

### 8.4 Hands-On Examples and Corrections

❌ Wrong:

```python
machine.succeed("echo 'hello'")
machine.screenshot("after-echo")  # not visible in the screenshot
```

✅ Correct:

```python
output = machine.succeed("echo 'hello'")
assert output.strip() == "hello"
print(f"verification output: {output.strip()}")   # visible in the logs
```

✅ If you really must see it on the graphical terminal (demo only):

```python
machine.send_key("alt-f2")
machine.wait_for_unit("getty@tty2.service")
machine.wait_until_tty_matches("2", "login: ")
machine.send_chars("root\n")                # needs passwordless root or autologin
machine.wait_until_tty_matches("2", "root@")
machine.send_chars("echo 'hello'\n")
machine.screenshot("tty2-hello")
```

---

## 9. Debugging and Advanced Techniques

### 9.1 Using `print` and `screenshot`

- `print()` output appears in the `nix build -L` logs and can also be viewed with `nix log`.
- The PNG from `screenshot` lives under `screenshots/` in the output directory; the path is printed in the build log.

### 9.2 Interactive Debugging and `test_script()`

Once the interactive driver (`driverInteractive`) has started, you can call `machine.start()`, `machine.succeed("...")`, and so on in the REPL. Calling `test_script()` executes the full test script, and you can keep inspecting state afterwards.

### 9.3 The SSH Backdoor Inside the Sandbox

Set this in the test module:

```nix
{
  enableDebugHook = true;
  sshBackdoor.enable = true;
}
```

Pass `/dev/vhost-vsock` at build time:

```bash
nix-build -A nixosTests.foo --option sandbox-paths /dev/vhost-vsock
```

On failure, follow the prompt into the sandbox and log into the VM with `ssh -F ./ssh_config vsock/3` (node numbering starts at 3). Running several tests at once can conflict; set `sshBackdoor.vsockOffset` in that case.

### 9.4 Early Failure Detection: `polling_condition`

```python
@polling_condition(seconds_interval=10, description="check nginx is alive")
def nginx_running():
    machine.succeed("pgrep nginx")

with nginx_running:
    # if nginx exits while this code block runs, the test fails immediately
    machine.succeed("stress --cpu 1 &")
```

### 9.5 Reusing Virtual-Machine State

```bash
./result/bin/nixos-test-driver --keep-vm-state
```

State is kept in `$TMPDIR/vm-state-machinename`, convenient for repeated debugging rounds.

---

## 10. Common Errors and Solutions

| Symptom                                                             | Cause                                                         | Fix                                                               |
| ------------------------------------------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------ |
| `option 'name' has no value`                                        | Using the low-level `runTest` without defining `name`         | Add `name`, or use `runNixOSTest`                                  |
| `option 'hostPkgs' has no value`                                     | Calling `lib.nixos.runTest` directly                           | Provide `hostPkgs`, or use `runNixOSTest`                          |
| `The option 'specialArgs' does not exist`                            | Using the nonexistent `specialArgs` option at the top level of `runNixOSTest` | Pass arguments via `_module.args` instead (see §12) |
| `attribute 'inputs' missing`, or a required external flake input unavailable | The test module expects an `inputs` parameter that was never injected | Inject via `_module.args = { inherit inputs; }` (see §12) |
| `machine` undefined in the test                                      | The node isn't named `machine`                                 | Keep names consistent — e.g. with `nodes.myNode`, use `myNode`     |
| Screenshot shows “Guest has not initialized the display (yet)”      | Screenshot taken before the graphics driver initialized       | Take screenshots after `wait_for_unit("multi-user.target")` or `wait_for_x()` |
| Command output invisible in the screenshot                           | The screenshot is the graphical screen; command output is on the serial console | Use the `succeed()` return value; for graphical-terminal output see 8.4 |
| `wait_for_console_text` times out                                    | Waiting before the command ran, or the regex doesn't match     | Make sure the command that produces the text has run; or use the `succeed` return value instead |
| `reboot()` fails in container mode                                   | The container shares the kernel                                | Simulate with `crash() + start()`, or switch to QEMU               |
| VSOCK address conflict (`Address already in use`)                   | Multiple tests enable the SSH backdoor at once                | Set `sshBackdoor.vsockOffset = 23542` or similar                   |
| OCR inaccurate or screenshots blurry                                | Screen resolution/fonts                                        | Add a `sleep`, or switch to `wait_for_console_text`                |
| Test passes but nothing is printed                                   | `nix flake check` only prints failing logs by default          | Use `nix build -L`, or view the full log with `nix log`             |
| Test times out                                                       | The default 3600-second global timeout may not fit             | Set `globalTimeout`, or the command-level `timeout` parameter     |

---

## 11. The Complete Test-Option Reference

Besides `nodes` and `testScript`, test modules support the following common options:

| Option                     | Type          | Default               | Description                                                       |
| -------------------------- | ------------- | --------------------- | ------------------------------------------------------------------ |
| `name`                     | string        | auto-generated        | Test name; affects derivation naming                               |
| `globalTimeout`            | int           | 3600                  | Global timeout (seconds)                                           |
| `enableOCR`                | bool          | false                 | Enables optical character recognition                              |
| `extraPythonPackages`      | function      | `_ : []`              | e.g. `p: [ p.numpy ]` (also set `skipTypeCheck=true`)              |
| `skipLint`                 | bool          | false                 | Skips the Black format check (for debugging; do not commit)        |
| `skipTypeCheck`            | bool          | false                 | Skips the type check                                               |
| `enableDebugHook`          | bool          | false                 | Pauses on failure and provides a debug interface                   |
| `interactive`              | submodule     | `{}`                  | Extra configuration in interactive mode (e.g. enabling graphics)   |
| `defaults`                 | NixOS module  | `{}`                  | Configuration applied to all nodes                                 |
| `extraBaseModules`         | NixOS module  | `{}`                  | Same as defaults, but cannot be overridden by specialisation       |
| `meta`                     | attr set      | `{}`                  | Can set `broken`, `maintainers`, `platforms`, `timeout`             |
| `qemu.package`             | package       | `hostPkgs.qemu_test`  | The QEMU package to use                                            |
| `sshBackdoor.enable`       | bool          | false                 | Enables the VSOCK SSH backdoor                                     |
| `sshBackdoor.vsockOffset`  | int           | 2                     | Avoids VSOCK address conflicts                                    |
| `node.pkgs`                | pkgs          | null                  | The nixpkgs instance the node uses                                 |
| `node.specialArgs`         | attr set      | `{}`                  | Extra arguments **passed to the node modules** (note: not to the test module) |
| `passthru`                 | attr set      | `{}`                  | Attributes attached to the final derivation                        |
| `hostPkgs`                 | pkgs          | automatic             | The nixpkgs used on the host side                                  |

See `nixos/lib/testing/*.nix` for the full list.

---

## 12. Passing External Arguments to Tests (Flake Inputs, etc.)

Most non-trivial tests need to pull configuration in from outside — e.g. `inputs.home-manager`, `inputs.sops-nix`. Test modules can receive these values through the `inputs`, `pkgs`, `lib`, and similar parameters, but `runNixOSTest` passes only the basic ones (`pkgs`, `lib`, ...) by default. For anything extra, **you must inject it via `_module.args`** — not via `specialArgs` (the test module has no `specialArgs` option).

### 12.1 Recommended: Set `_module.args` Inside `runNixOSTest`

Create a common test runner (e.g. in `tests/default.nix`):

```nix
{ inputs, shared, ... }:
let
  pkgs = shared.pkgs;

  # the recommended higher-order test runner: injects inputs automatically for all test modules
  nixosTest = path: pkgs.testers.runNixOSTest {
    _module.args = { inherit inputs; };   # pass the flake inputs to the test module
    imports = [ path ];
  };
in
...
```

Use this runner in the `checks` of `flake.nix`:

```nix
checks.x86_64-linux.integration-test = nixosTest ./tests/integration/my-test.nix;
```

### 12.2 The Declaration on the Test-Module Side

The test module simply declares the parameter of the same name — no default value needed anymore:

```nix
{ pkgs, lib, inputs, ... }:
{
  # inputs.home-manager and friends can now be used directly
  nodes.machine = { ... }: {
    imports = [ inputs.home-manager.nixosModules.home-manager ];
    ...
  };
  testScript = ''...'';
}
```

### 12.3 If You Only Want to Pass a Specific Argument to One Test

You can also add `_module.args` in a single test file:

```nix
{
  _module.args.myCustomArg = "hello";
  nodes.machine = { ... };
  ...
}
```

**Notes**:

- `node.specialArgs` is a test option that passes arguments to the **node modules** — not to the test module itself.
- Do not write `specialArgs` among the top-level arguments of `runNixOSTest`, or you will get the error `option 'specialArgs' does not exist`.

### 12.4 Example: A Complete Test Integrating home‑manager

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

Then just use the aforementioned `nixosTest` wrapper in the checks of `flake.nix`.

---

## 13. Overriding Tests and Linked Packages

### 13.1 `extendNixOS` / `extend`

Inject extra modules or arguments into all nodes without modifying the original test:

```nix
nixosTests.openssh.extendNixOS {
  module = { services.openssh.package = myCustomPkg; };
  specialArgs = { myArg = "value"; };
}
```

The generic `extend` function can also be used to add test modules.

### 13.2 `overrideTestDerivation`

Modify the test's derivation directly, e.g. to add extra dependencies:

```nix
myTest.overrideTestDerivation (prevAttrs: {
  buildInputs = prevAttrs.buildInputs ++ [ extraPkg ];
})
```

### 13.3 `passthru.tests` Integration

Link tests to a package so they run automatically when the package updates:

```nix
stdenv.mkDerivation {
  ...
  passthru.tests.nixos = nixosTests.my-service.extendNixOS {
    module = { services.myService.package = finalAttrs.finalPackage; };
  };
}
```

---

## 14. Performance-Optimization Tips

- **Prefer container mode**: use `containers` for service-layer tests — fast startup, low memory.
- **`virtualisation.useHostStore = true`**: mounts the host store in QEMU mode, avoiding copies.
- **`virtualisation.memorySize`**: the default is 1024 MiB; shrink it when testing lightweight services.
- **Pure logic via `runCommand`**: no VM is started; it runs directly in the build sandbox.
- **Caches and mirrors**: use `cachix` or a domestic mirror to speed up the first build; subsequent builds hit the Nix cache automatically.

---

## 15. Summary and the Road Ahead

✅ Having worked through this handbook, you now know how to:

- Write and run NixOS test modules
- Choose between the QEMU and systemd-nspawn container backends
- Extract command output, serial logs, and screenshots precisely
- Integrate tests into a Flake, with automatic scanning and management
- Debug failing tests: interactive REPL, SSH backdoor, screenshots, logs
- Avoid common errors such as missing `name`/`hostPkgs`, container reboot, and VSOCK conflicts
- Pass external flake inputs to test modules safely (`_module.args`)

📚 Suggested next steps:

1. Write tests for core services (databases, web services, encrypted mounts, etc.)
2. Build multi-node tests (client-server, failover)
3. Run `nix flake check` in CI (GitHub Actions), archiving screenshots
4. Contribute tests to Nixpkgs — see the official examples in `nixos/tests/`

---

## 16. Appendix: Complete Examples and Official Resources

### Official Test Examples

- **login.nix**: user login, VT switching, device-permission verification
- **nfs/simple.nix**: multi-node NFS locking, crash recovery
- **fcitx5.nix**: input-method graphical tests (OCR, window matching)

### Official Documentation

- [Official NixOS Tests manual](https://nixos.org/manual/nixos/stable/index.html#sec-nixos-tests)
- [Nixpkgs test-contribution guide](https://nixos.org/manual/nixpkgs/stable/#sec-testing)

### A Comprehensive Example: A Service Test with OCR and polling_condition

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

    with subtest("open the browser and verify the title"):
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
