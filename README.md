# 🧊 Nix Config: 声明式系统与开发环境管理

![Nix Architecture](https://via.placeholder.com/800x300?text=Declarative+System+%26+Dev+Environments)

**作者**: [@Redskaber](https://github.com/Redskaber)  
**状态**: 🏆 生产就绪 • 🔄 持续演进 • 🔐 安全优先

> 一套工业级 Nix 配置系统，融合声明式基础设施与函数式编程原则，为多平台环境提供统一、可复现的开发体验。

## 🌟 核心价值

- **分离关注点**：系统层最小化，用户层丰富化
- **安全至上**：敏感数据端到端加密，最小权限原则
- **开发优先**：语言专属环境，无全局污染
- **可组合性**：管道驱动架构，组件自由组合
- **声明式**：从状态管理到体验设计，一切皆声明

## 🏗️ 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                        FLAKE.NIX                            │
│  (统一入口 • 多系统支持 • 依赖管理 • 构建策略)              │
└───────────────┬───────────────────────────┬─────────────────┘
                │                           │
┌───────────────▼─────────────┐ ┌───────────▼──────────────────┐
│        SYSTEM LAYER         │ │        USER LAYER            │
│ (NixOS • 硬件 • 驱动 • 安全)│ │ (Home Manager • Apps • Dev)  │
└───────────────┬─────────────┘ └───────────┬──────────────────┘
                │                           │
┌───────────────▼─────────────┐ ┌───────────▼──────────────────┐
│        LIBRARY LAYER        │ │        SECRET LAYER          │
│ (抽象 • 管道 • 验证 • 策略) │ │ (SOPS • Age • 最小权限)      │
└─────────────────────────────┘ └──────────────────────────────┘
```

### 📂 详细目录结构

```bash
├── 📁 export/               # 可重用模块 (导出给其他 flakes)
│   ├── 📁 home/             # Home Manager 模块
│   └── 📁 nixos/            # NixOS 模块
├── 📁 home/                 # Home Manager 配置
│   ├── 📁 core/             # 核心配置
│   │   ├── 📁 app/          # 应用程序 (GUI/CLI)
│   │   ├── 📁 dev/          # 开发环境 (语言专属)
│   │   ├── 📁 srv/          # 服务 (mako, playerctld)
│   │   └── 📁 sys/          # 系统工具 (shell, git, fonts)
│   ├── 📁 hosts/            # 主机特定配置
│   │   ├── linux.nix        # 通用 Linux
│   │   ├── nixos.nix        # NixOS 主机
│   │   ├── macos.nix        # macOS
│   │   └── wsl.nix          # WSL2
│   ├── 📁 theme/            # UI 主题 (Wayland 生态)
│   └── 📁 wm/               # 窗口管理器 (Hyprland)
├── 📁 lib/dev/              # 开发环境核心架构
│   ├── mk-pdshell.nix       # 管道驱动 Shell 构建器
│   └── pdshells.nix         # 自动加载器与验证
├── 📁 nixos/                # NixOS 系统配置
│   ├── configuration.nix    # 系统入口
│   └── 📁 core/             # 系统核心
│       ├── 📁 drive/        # GPU 驱动 (NVIDIA/AMD/Intel)
│       ├── 📁 security/     # 安全子系统
│       │   └── 📁 secret/   # SOPS-Nix 集成
│       └── 📁 srv/          # 系统服务 (DB, Desktop, Hardware)
└── 📁 secrets/              # 加密凭据 (由 SOPS 管理)
    ├── 📁 db/               # 数据库凭据
    └── secrets.yaml         # 系统凭据
```

## ⚡ 革命性的开发环境系统

### 管道驱动架构 (Pipeline-Driven Architecture)

```mermaid
graph LR
    A[组合定义] --> B[策略解析]
    B --> C[输入合并]
    C --> D[钩子组合]
    D --> E[验证]
    E --> F[Shell 生成]
```

**核心组件**:
- **组合器** (`combinFrom`): 合并多个语言环境
  ```nix
  cpython = {
    combinFrom = [ dev.c dev.python ];
    # 自动合并 buildInputs, nativeBuildInputs, shellHooks
  };
  ```
- **生命周期钩子**:
  - `preInputsHook`: 输入前执行
  - `postInputsHook`: 输入后、shell 前执行
  - `preShellHook`/`postShellHook`: 进入/退出 shell 时执行
- **策略模式**: 为不同文件类型提供可插拔处理逻辑

### 语言环境示例: 机器学习 (`python-machine.nix`)

```nix
{
  buildInputs = with pkgs; [
    python312 uv ruff pyright  # 核心工具
    gcc.cc.lib nodejs_24       # 依赖注入
  ];
  
  postInputsHook = ''
    # 环境隔离
    export PYTHONPYCACHEPREFIX="$PWD/.cache/python"
    export UV_CACHE_DIR="$PWD/.cache/uv"
    
    # GPU 支持提示
    echo "For CUDA support: uv add torch==2.5.1 --extra-index-url https://download.pytorch.org/whl/cu121"
  '';
  
  postShellHook = ''
    echo "快速入门:"
    echo "  uv init && uv venv && source .venv/bin/activate"
    echo "  uv add numpy pandas scikit-learn"
  '';
}
```

## 🔐 安全模型：凭据管理

### 端到端加密流程
```
1. 密钥生成: age-keygen → ~/.config/sops/age/keys.txt
2. 加密: sops encrypt secrets.yaml
3. 提交: 加密文件提交到 Git
4. 运行时: initrd 阶段解密 → /run/secrets
5. 应用: 服务通过符号链接访问凭据
```

### 最小权限设计
```nix
sops.secrets."nixos/srv/db/postgresql/users/redskaber/password" = {
  mode = "0440";  # 仅所有者可读
  owner = config.users.users.root.name;
  group = config.users.users.postgres.group;  # 精确组权限
  path = "/run/secrets/nixos/srv/db/postgresql/users/redskaber/password";
};
```

## 🚀 快速入门

### 安装与部署
```bash
# 克隆仓库
git clone https://github.com/Redskaber/nix-config ~/.config/nix-config
cd ~/.config/nix-config

# NixOS 系统部署
sudo nixos-rebuild switch --flake .#kilig-nixos

# Home Manager (NixOS)
home-manager switch --flake .#kilig@nixos

# 非 NixOS Linux
nix run .#install-standalone  # 安装 Home Manager
home-manager switch --flake .#kilig@linux
```

### 进入开发环境
```bash
# 基础 Python 环境
nix develop .#python

# 机器学习环境 (带 GPU 支持提示)
nix develop .#python-machine

# 复合环境: C + Python
nix develop .#cpython

# Rust 环境 (无需 rustup)
nix develop .#rust
```

## 🛠️ 高级用法

### 临时开发环境组合
```bash
nix develop .#default --command bash -c '
  # 临时组合环境
  nix develop .#python-machine --command python3 train.py
'
```

### 导出环境配置
```bash
# 生成 direnv 配置
nix develop .#python-machine --command cat > .envrc <<EOF
use flake .#python-machine
EOF

# 启用
direnv allow
```

### 故障排除
```bash
# 跟踪 shell 构建过程
nix develop .#python-machine --show-trace

# 检查依赖图
nix why-depends .#python-machine python312 uv

# 验证凭据访问
sudo ls -la /run/secrets
```

## 🌐 跨平台支持

| 平台        | 系统层支持 | 用户层支持 | 开发环境 | 备注                     |
|------------|-----------|-----------|---------|--------------------------|
| NixOS x86_64 | ✅ 完整    | ✅ 完整       | ✅ 全部  | 主要开发平台              |
| Linux x86_64 | ❌ 无      | ✅ 完整(待校验)| ✅ 全部  | 通过 Home Manager 独立使用 |
| macOS ARM64  | ❌ 无      | （未接触）    | ⚠️ 部分  | CLI 工具为主              |
| WSL2         | ❌ 无      | （未接触）    | ✅ 全部  | 需手动启用 systemd        |

## 🤝 贡献指南

1. **添加新应用**:
   - GUI 应用: `home/core/app/<category>/<app>.nix`
   - CLI 工具: `home/core/sys/<tool>.nix`
   - 遵循现有命名约定

2. **添加语言环境**:
   ```bash
   mkdir -p home/core/dev/<lang>
   cp home/core/dev/python/default.nix home/core/dev/<lang>/default.nix
   # 修改内容
   ```

3. **修改系统配置**:
   - 优先通过选项而非覆盖
   - 为新功能创建独立模块
   - 保持 `nixos/configuration.nix` 简洁

4. **安全第一**:
   - 敏感数据必须通过 SOPS 加密
   - 永远不要提交明文凭据
   - 使用 `sops exec-env` 测试变更

## 📈 路线图

- [ ] **渐进式评估**: 惰性加载大型模块，提高评估速度
- [ ] **测试套件**: 为关键路径添加 NixOS 测试
- [ ] **文档生成**: 自动生成模块文档和依赖图
- [ ] **移动支持**: Nix on Android (Termux) 配置
- [ ] **Dev Container**: 集成 VSCode Dev Containers

## 💡 哲学洞见

> "这不是一个配置集合，而是一个**可编程的环境操作系统**。"
>
> 每个文件都是函数，每个目录都是模块，每次重建都是纯函数推导。我们不是在配置机器，而是在定义体验——从内核参数到字体渲染，一切皆为函数式表达。
>
> 通过管道架构，我们实现关注点分离：系统维护者关注稳定性，开发者关注生产力，安全工程师关注凭据——所有人在同一套声明式语言中共存。

---

📖 **深入探索**: 每个模块顶部的元注释包含详细设计说明与使用示例。  
💬 **问题与讨论**: [创建 Issue](https://github.com/Redskaber/nix-config/issues) 或提交 PR。  
✨ **灵感来源**: NixOS 模块系统、Home Manager、SOPS-Nix、Nix Flakes 模型。

> 最后更新: 2026年3月1日 • 构建于 Nix 2.22+ • 兼容 NixOS 25.11



