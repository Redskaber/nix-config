# CI/CD 深度手册 — 缘起、本地预检与部署流

> 本文收纳 README「CI/CD 完整执行流」节的深度部分（T13.1 分层重构时迁出）：
> 为什么需要 CI/CD、本地预检清单、部署工作流、世代管理与回滚、自动化更新。
> 流水线全景图与缓存策略见 [README](../../README.md#cicd-完整执行流)。

### 为什么 Nix 配置需要 CI/CD

每次变更 nix-config 都等价于声明一个新的系统状态。CI 的核心价值：

1. **求值检查** — 捕获 Nix 语法/类型错误（早于 nixos-rebuild 失败）
2. **深层求值** — 面分片强制（T15.1）：api 信封 + 逐主机 toplevel drvPath + 杂项 checks + 完备性对账（全部 95 checks 必须被平面或杂项清单拥有；单进程 `nix flake check` 因内存累积地板已退役）
3. **Secret 完整性** — 验证加密文件结构正确，`secrets/plan/` 未被提交
4. **测试覆盖** — 93 tests 覆盖 nixos/home/lib/integration/nmt 平面
5. **自动更新** — 每周日自动更新 flake inputs 并开 PR

---

### 本地预检清单（push 前）

```bash
# 1. 静态检查
nix run nixpkgs#statix -- check .

# 2. 结构验证（无构建，无 sopsFile 触发）
nix eval .#nixosConfigurations --apply builtins.attrNames --json
nix eval .#homeConfigurations  --apply builtins.attrNames --json
nix eval .#checks.x86_64-linux --apply builtins.attrNames --json

# 3. nmt 平面（最快，< 30s，无 QEMU）
nix eval .#checks.x86_64-linux --apply \
  'cs: builtins.attrNames (builtins.filterAttrs (n: _: builtins.substring 0 4 n == "nmt_") cs)' \
  --json | python3 -c "import sys,json; [print(c) for c in json.load(sys.stdin)]" \
  | xargs -I{} nix build ".#checks.x86_64-linux.{}" --no-link

# 4. devShell dry-run
nix build .#devShells.x86_64-linux.rust --dry-run --no-link

# 5. secret 文件验证
find secrets/chipr -name "*.yaml" | xargs grep -L "^sops:" 2>/dev/null \
  && echo "ERROR: plaintext files found" || echo "OK"
```

### 部署工作流

```
开发机 (本地)                        生产机 (NixOS)
    │                                      │
    ├── edit *.nix                         │
    ├── nix eval ... (structure check)     │
    ├── git push → CI (GitHub Actions)     │
    │       └── 7 stage passes             │
    │                                      │
    └── [CI Pass]                          │
        │   cd /etc/nix-config             │
        │   git pull                       │
        │                                  │
        │   just nixos-switch nixos        │  # => sudo nixos-rebuild switch --flake .#nixos
        │                                  │
        │   just home-switch nixos         │  # => home-manager switch --flake .#kilig@nixos
        │                                  │
        └── systemctl status sops-*        │
            just secret-get mongodb        │
```

### 世代管理与回滚

```bash
# 列出可用系统世代
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# 回滚到上一代
sudo nixos-rebuild switch --rollback

# 回滚到指定世代
sudo nix-env --profile /nix/var/nix/profiles/system --switch-generation <N>
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

### 自动化更新

每周日 UTC 03:00，`.github/workflows/update-flake.yml` 自动：

1. `nix flake update` 更新所有 inputs
2. 生成 `flake.lock` diff 摘要
3. 开 PR（branch: `automation/update-flake-inputs`，label: `dependencies automated`）
