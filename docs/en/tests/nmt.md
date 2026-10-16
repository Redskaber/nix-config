# NMT (NixOS Module Tests) — the complete guide: from zero to mastery

> English mirror of [docs/tests/nmt.md](../../tests/nmt.md) — the Chinese original is the canonical source; this plane is asserted at file-existence level by the docs-ssot en-parity battery.

> [nmt test](https://deepwiki.com/search/nixos-homemanager-nmt-test-fra_5995e254-423c-4042-9e48-b13b5703b302)

## 1. What is NMT?

NMT (NixOS Module Tests) is a lightweight test framework designed specifically
for the **NixOS module system**. Its core idea is **"package scrubbing"**: at
test-evaluation time, real packages (derivations) are replaced with placeholder
strings (such as `@packageName@`), thereby avoiding the expensive
package-build process. This lets tests **quickly verify a module's
configuration logic, generated files, and systemd units** without actually
downloading or compiling any software.

You can think of NMT as **the "unit-test" framework for NixOS modules**. It is
fundamentally different from NixOS's traditional integration tests:

| Feature            | NMT (module tests)                          | NixOS integration tests (VM tests)                    |
| ------------------ | ------------------------------------------- | ------------------------------------------------------ |
| **Test target**    | Module configuration logic, generated files  | Full system behavior, service interaction             |
| **Build overhead** | Very low (no packages built)                 | High (packages must be built/downloaded, VMs booted)   |
| **Run speed**      | Fast (seconds)                              | Slow (minutes)                                         |
| **Focus**          | Configuration correctness                   | System-integration correctness                        |

NMT was originally developed by the Home Manager project, but its design is
general — **any project using the Nixpkgs module system can use it**.

## 2. Core principle: package scrubbing

### 2.1 Why is package scrubbing needed?

In a Nix module test, if you reference a package path (for example
`${pkgs.i3lock}/bin/i3lock`), Nix will normally attempt to build or download
that package. For testing module configuration logic, this is both
unnecessary and extremely time-consuming.

### 2.2 The `scrubDerivation` function

NMT solves this with the recursive function `scrubDerivation`. It walks the
attribute set and replaces every derivation's `outPath` with the placeholder
string `"@packageName@"` while blocking the actual build. Its key attribute
mapping:

| Attribute              | Purpose                | Value                          |
| ---------------------- | ---------------------- | ------------------------------ |
| `buildScript`          | Block the actual build | `abort "no build allowed"`      |
| `outPath`              | Placeholder string     | `"@${lib.getName value}@"`     |
| `outputSpecified`      | Stop output traversal  | `true`                         |
| `__spliced.buildHost`  | Preserve input usage   | the original derivation        |

For example, `pkgs.i3lock` becomes `"@i3lock@"`, bypassing the build entirely.

### 2.3 The whitelist system

Certain foundational packages (such as `coreutils`, `jq`, `bash`) must be
**actually executed** in tests (for example, to run activation scripts or shell
configuration). Such packages are whitelisted to skip scrubbing:

```nix
whitelist = let
  inner = _self: _super: {
    inherit (pkgs)
      coreutils crudini jq desktop-file-utils diffutils
      findutils glibcLocales gettext gnugrep gnused
      shared-mime-info emptyDirectory babelfish fish lndir;
  };
in outer;
```

### 2.4 Darwin special handling

The `stdenv` of Darwin systems is more involved and needs a dedicated scrub
list. Darwin tests import a separate `darwinScrublist.nix`, which holds the
scrubbing definitions for the Darwin-specific packages.

## 3. Environment setup

### 3.1 Obtaining NMT

NMT exists as a standalone library. Home Manager pulls it in via
`fetchTarball`:

```nix
nmtSrc = fetchTarball {
  url = "https://git.sr.ht/~rycee/nmt/archive/v0.5.1.tar.gz";
  sha256 = "0qhn7nnwdwzh910ss78ga2d00v42b0lspfd7ybl61mpfgz3lmdcj";
};
```

It can also be installed from Nixpkgs (experimental):

```bash
nix-env -iA nixpkgs.nix-lib-nmt
```

### 3.2 Basic project structure

Home Manager's test infrastructure lives under the `tests/` directory:

```
tests/
├── default.nix          # 测试入口，定义擦洗逻辑、模块集合和测试发现
├── modules/             # 模块测试用例（按类别组织）
│   ├── programs/        # 可自动发现
│   └── services/        # 可自动发现
├── integration/         # 集成测试（NixOS/standalone）
│   ├── default.nix
│   ├── nixos/           # 基于 NixOS 的集成测试
│   └── standalone/      # 独立集成测试
├── lib/                 # 测试辅助库
├── asserts.nix          # 自定义断言（警告与断言校验）
├── big-test.nix         # 大型测试标记
├── stubs.nix            # 包桩定义
└── tests.py             # 测试运行辅助脚本
```

### 3.3 Key structure of `tests/default.nix`

The test suite's entry file defines the core infrastructure, with these key
parts:

1. **Bring in the NMT framework** (`nmtSrc`)
2. **Define the core package-scrubbing logic** (`scrubDerivation`,
   `scrubDerivations`)
3. **Configure the whitelist and the Darwin special handling** (`whitelist`,
   `darwinScrublist`)
4. **Produce the scrubbed nixpkgs instance** (`scrubbedPkgs`): on Linux,
   traverse and scrub all packages, then apply the whitelist; on Darwin, use
   the dedicated scrub list
5. **Load the modules under test**: `modules = import ../modules/modules.nix { ... }`
6. **Inject the test configuration**: e.g. keeping the real nixpkgs module
   machinery from running, fixing the username and home directory, and so on
7. **Test discovery**: explicitly list the core test modules, and
   automatically scan every directory under `modules/programs` and
   `modules/services`

## 4. Writing your first NMT test

### 4.1 The basic test-file template

Every test file is a Nix expression holding one module configuration plus a
set of `nmt.script` assertions. Taking ledger as the example:

```nix
{ config, lib, pkgs, ... }:

{
  # 模块配置部分
  programs.ledger = {
    enable = true;
    settings = {
      sort = "date";
      strict = true;
    };
  };

  # 测试断言部分
  nmt.script = ''
    assertFileExists home-files/.config/ledger/ledgerrc
    assertFileContent home-files/.config/ledger/ledgerrc \
      ${builtins.toFile "ledger-expected-settings" ''
        --sort date
        --strict
      ''}
  '';
}
```

### 4.2 Test organization and discovery

Test files must sit inside the conventional directory layout, where NMT
discovers them automatically:

```
tests/modules/<category>/<module>/<test-name>.nix
```

For example:

- `tests/modules/programs/ledger/ledger.nix`
- `tests/modules/services/screen-locker/basic-configuration.nix`

Each module directory needs a `default.nix` to export its tests.

### 4.3 Common assertion functions

NMT provides a set of assertion functions for checking generated files:

| Function                                | Purpose                                      | Example                                    |
| --------------------------------------- | -------------------------------------------- | ------------------------------------------ |
| `assertFileExists <path>`               | Verify the file exists                       | `assertFileExists home-files/.zshrc`       |
| `assertPathNotExists <path>`            | Verify the path does not exist               | `assertPathNotExists home-files/.bad`      |
| `assertFileRegex <path> <regex>`        | Check file content against a regex           | `assertFileRegex $file 'pattern'`          |
| `assertFileNotRegex <path> <regex>`     | Verify the file does **not** match the regex | `assertFileNotRegex $file 'bad-pattern'`   |
| `assertFileContent <actual> <expected>` | Compare file content exactly                 | `assertFileContent $actual $expected`      |

#### 4.3.1 `assertFileContent` in depth

This assertion verifies file content exactly. The expected content can be
defined inline or imported from an external file:

```nix
nmt.script = ''
  # 内联期望内容
  assertFileContent home-files/result.txt ${
    pkgs.writeText "expected.txt" ''
      This is the expected content
      line 2
    ''
  }

  # 从文件导入期望内容
  assertFileContent home-files/result.txt ${./expected-result.txt}
'';
```

### 4.4 Package stubbing with `test.stubs` and `test.stubOverlays`

NMT provides a two-layer stubbing mechanism:

1. **Declarative stubs (`test.stubs`)**: replace the packages of the given
   names with `mkStubPackage`; a stub package's `outPath` defaults to `@name@`,
   and attributes such as version or build script can be specified.
2. **Programmatic stubs (`test.stubOverlays`)**: modify the package set
   directly (much like an overlay), allowing fine-grained control over stub
   behavior. This option is an internal one, generated automatically from
   `test.stubs` and `test.unstubs`.

```nix
# 声明式桩：简单替换
test.stubs.my-package = { name = "my-package"; };

# 编程式桩：使用 overlay 进行更复杂的替换
test.stubOverlays = [
  (self: super: {
    my-package = pkgs.writeScriptBin "my-package" ''
      #!/bin/sh
      echo "stub"
    '';
  })
];
```

### 4.5 Platform-specific tests

NMT supports filtering tests by platform:

```nix
{ config, lib, pkgs, ... }:

{
  services.xserver.enable = lib.mkIf pkgs.stdenv.isLinux true;

  nmt.script = lib.mkIf pkgs.stdenv.isLinux ''
    assertFileExists home-files/.xsession
  '';
}
```

### 4.6 Big tests and legacy IFD

**Big tests**: for fast development iteration, the slower tests can be
flagged as "big tests". They are enabled by default but can be controlled via
the `enableBig` parameter.

**Legacy IFD**: for legacy code still using "Import From Derivation",
support can be enabled:

```nix
{ config, lib, pkgs, ... }:
{
  test.enableLegacyIfd = true;
}
```

The option is passed to the test entry point via the `enableLegacyIfd`
parameter.

### 4.7 Custom assertion extensions (warnings and assertions)

Home Manager ships an extended assertion set in `tests/asserts.nix` for
verifying the **warnings** and **assertions** a module produces. Once turned
on via `test.asserts.warnings.enable` and `test.asserts.assertions.enable`,
it automatically collects the messages, generates the actual-content file,
and compares it against the expected list.

```nix
test.asserts = {
  warnings.expected = [ "This is a warning" ];
  assertions.expected = [ "Assertion failed: ..." ];
};
```

## 5. Test execution and workflow

### 5.1 Running tests locally

The most basic invocation:

```bash
nix-build tests/default.nix
```

This evaluates all tests. You can also build only a specific test:

```bash
nix-build tests/default.nix -A tests.modules.programs.ledger.ledger
```

Home Manager additionally provides a Python test runner, `tests/tests.py`,
for more flexible test execution.

### 5.2 Test output and debugging

When a test fails, you will see output like this:

```
Error: assertion failed:
  assertFileExists home-files/.ledgerrc
  File does not exist.

TESTED: /nix/store/...-test-ledger-ledger

Hint: look at the TESTED path to inspect the generated output.
```

You can enter the `$TESTED` directory and inspect the actually generated
files to debug:

```bash
ls $TESTED/home-files
```

### 5.3 CI/CD integration

Home Manager's CI uses GitHub Actions and implements smart test chunking:

- **Path filtering**: `dorny/paths-filter` runs only the tests related to the
  changed files.
- **Test chunking**: the test set is split into chunks executed in parallel,
  roughly 50 tests per chunk. Each chunk is exposed as its own package (e.g.
  `test-chunk-1`, `test-chunk-2`) and can be built individually with
  `nix build ./tests#test-chunk-1`.

## 6. Advanced topics

### 6.1 Integration tests

Under `tests/integration/`, Home Manager provides integration tests, split
into NixOS-based tests and standalone tests. They verify module behavior in
more realistic environments and complement NMT's fast module tests.

### 6.2 Test-maintainer automation

Home Manager CI includes automatic reviewer assignment. It works by analyzing
the changed modules' `meta.maintainers` field — `lib/nix/extract-maintainers.nix`
extracts the maintainer information, and a Python script then orchestrates
the flow.

## 7. Summary of best practices

1. **Keep tests small and focused**: each test should verify exactly one
   specific feature or configuration option.
2. **Use stubs to isolate external dependencies**: keep tests from failing
   because an external service is unavailable.
3. **Prefer verifying generated file content**: NMT's core strength is
   file-content checking — make full use of `assertFileContent` and
   `assertFileRegex`.
4. **Write tests for new modules**: when adding a new module, write the
   corresponding test cases in the same change.
5. **Exploit platform filtering**: make sure tests run only on the target
   platforms, avoiding cross-platform false positives.
6. **Mind whitelist maintenance**: if a test needs to really execute a
   package, remember to add it to the whitelist.
7. **Follow the naming convention**: test files belong at
   `tests/modules/<category>/<module>/<test-name>.nix`.
8. **Leverage the exactness of `assertFileContent`**: for configuration
   files, use exact content comparison to guarantee full conformance to
   expectations.

## 8. Frequently asked questions

**Q: How does NMT differ from Nixpkgs's `lib.debug.runTests`?**
A: `runTests` is for testing pure Nix functions (library code), while NMT is
designed for the module system and can verify module evaluation results and
generated files.

**Q: How do I test complex scenarios that need real builds?**
A: For tests that need full system interaction, use the NixOS VM integration
tests; NMT is for verifying module configuration logic only.

**Q: Can NMT be used in non-Home-Manager projects?**
A: Yes. NMT is a standalone library; any project using the Nixpkgs module
system can integrate it.

**Q: How do I debug a failing test run?**
A: Check the `$TESTED` environment variable or the path in the failure
output, and look directly at the generated files under that directory.

**Q: Why did my test trigger a package build?**
A: You probably used an unscrubbed package path, or the package is not in
the whitelist. Check whether you reference it directly via `${pkgs.xxx}`.

## 9. Reference resources

- [NMT source repository](https://git.sr.ht/~rycee/nmt)
- [Home Manager tests directory](https://github.com/nix-community/home-manager/tree/master/tests)
- [NMT Testing Framework deep-dive documentation](https://deepwiki.com/nix-community/home-manager/5.1-nmt-testing-framework)
- [Home Manager CI/CD Pipeline](https://deepwiki.com/nix-community/home-manager/5.2-cicd-pipeline)
- [NixOS integration-test tutorial](https://nix.dev/tutorials/nixos/integration-testing-using-virtual-machines.html)

This tutorial was written against NMT v0.5.1 and the Home Manager master
branch's test infrastructure. As the projects evolve, the concrete
implementation may change; when in doubt, the latest source code is the
authority.

---

## 10. This repository's consumption shape (the nix-config side)

> This section is nix-config's **actual consumption contract** for nmt —
> beyond the generic tutorial above: what this repository has hard-pinned, and
> what it depends on.

### 10.1 The input, and why the mirror exists

```nix
# flake.nix
nmt.url = "github:Redskaber/nmt";
nmt.flake = false;   # 原始 store path，无 flake 产物
```

The upstream `git.sr.ht:~rycee/nmt` returns HTTP 403 to Nix fetchers (bot
protection), and `github.com/Redskaber/nmt` is the accessible mirror —
locking the rev is locking the consumed content.

### 10.2 The fork delta (from pinned rev 25fe4c8 onward)

1. **The `--` end-of-options guard**: the three grep assertions
   (`assertFileContains` / `assertFileRegex` / `assertFileNotRegex`) pass
   `--` before the needle — an option-styled needle (`"--smart-case"`) is
   matched as text instead of being parsed as a flag. What this means for
   this repository's nmt plane: the `contains` / `regex` fields **accept
   needles with a leading dash** (the driver-layer comment guarantees the
   same sentence; before T27.2 this spot was a CRITICAL workaround segment —
   the "a needle must not start with `-`" detour has been retired).
2. **The `test/` self-test battery** (on the fork's evolve branch, delivered
   via the web download interface): the test framework tests its own
   assertion library — 39 cases in three classes (positive path / negative
   path — the framework must be able to go red exactly where red is due /
   adversarial needle — the guard-regression class, including the mirror
   case: an absent option-styled needle must still go red). Standalone:
   `bash test/battery.sh` or `nix build -f test/`.

### 10.3 The consumption-grade regression proof (test #98)

`nmt_home_core_exp_sys_base_ripgrep`:
`programs.ripgrep.arguments → .config/ripgrep/ripgreprc` (plain text, one
flag per line), asserting `contains = [ "--smart-case" "--colors=auto" ]` —
the needle travels `contains` → `escapeShellArg` → `assertFileContains` →
`grep -qF --`, **the whole chain flowing through the guard**. Mutation
check: `--override-input nmt github:Redskaber/nmt/0aa4699` (the pre-guard
rev) → the grep error `unrecognized option '--colors=auto'` reproduces verbatim —
the missing guard is a one-line red on the consumption side.

### 10.4 Fork governance (re-sync and bump discipline)

- **The re-sync cadence**: the fork's reason to exist is that the sourcehut
  primary returns 403 to Nix fetchers (for mirroring, not for forking) —
  whenever upstream (rycee/nmt) evolves, the fork follows via a "rebase
  delta" (the delta is only two items: the `--` guard + the self-test
  battery), never letting the delta drift into two trees.
- **The bump dual safety nets**: flake.lock pins WHERE (currently 25fe4c8 —
  the landed state of the delta guard), tests/ pins WHAT (test #98 + the
  nmt plane's 16 tests are themselves the consumption-grade proof); a bump
  is invariably "lock + full gates in the same commit" — see
  [external-repos.md §4](../architecture/external-repos.md).
- **Pending-state note**: the fork HEAD's self-test battery commit (010158b)
  is not yet consumed by this repository's lock — being one commit ahead is
  the norm (sandbox reference copy ≠ lock consumption), and whether to bump
  is adjudicated by the owner as needed.
