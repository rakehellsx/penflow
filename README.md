# PenFlow — 内网渗透工作流编辑器

> 基于 Flutter 构建的跨平台桌面客户端，兼容 **Windows** 和 **Linux** 运行。

---

## 功能特性

### 核心功能

| 功能 | 说明 |
|------|------|
| 可视化工作流编辑器 | 拖拽节点、贝塞尔曲线连线、画布缩放/平移、网格背景 |
| 任务管理系统 | 创建/列表/删除任务，通过压缩包导入工作流+载荷+文档 |
| 工具箱 | 8 大分类 30+ 内置工具，支持搜索过滤、拖拽到画布、侧边栏收缩 |
| 虚拟机管理 | 对接 VMware Workstation（Windows）/ KVM-QEMU（Linux） |
| 账号登录 | SQLite3 存储账号密码（SHA-256 哈希），支持修改密码 |
| 黑/白皮肤切换 | 顶部工具栏一键切换，状态持久化 |

### 任务管理

任务通过 `.zip` 压缩包导入，约定目录结构如下：

```
task.zip
├── workflow.json      <- 工作流文件（必须）
├── payloads/          <- 载荷工具（可选）
│   ├── exploit.py
│   └── shell.elf
└── docs/              <- 工具文档（可选，.md / .txt）
    ├── mimikatz.md
    └── bloodhound.md
```

- 创建任务后，工作流自动加载到画布
- 载荷工具和文档自动注入到工具箱（动态分类）
- 点击任务列表中的任意任务可重新激活

### SQLite 持久化

数据库路径：
- Linux：`~/.local/share/penflow/penflow_tasks.db`
- Windows：`%APPDATA%\penflow\penflow_tasks.db`

| 表名 | 存储内容 |
|------|----------|
| tasks | 任务名称、描述、工作流文件路径、压缩包路径、工作流 JSON、创建时间、更新时间 |
| task_files | 任务关联文件（载荷 + 文档），含本地路径和文件大小 |
| node_vm_binds | 画布节点 -> 虚拟机绑定（VM ID、名称、IP、OS类型、后端类型、绑定时间） |
| penflow_auth.db | 账号密码（SHA-256 哈希存储） |

### 虚拟机管理接口

| 平台 | 后端 | 接口方式 |
|------|------|----------|
| Windows | VMware Workstation | vmrest.exe REST API，http://127.0.0.1:8697/api，Basic Auth |
| Linux | KVM/QEMU libvirt | virsh 命令行调用，支持 list/start/shutdown/reboot/suspend/undefine |

进入虚拟机（节点卡片"进入虚拟机"按钮）：
- Linux：优先 virt-viewer，降级到 remote-viewer，最终 virsh console
- Windows：优先 vmrun.exe gui，降级到 vmplayer.exe、vmware.exe

---

## 快速开始

### Linux 运行

```bash
tar -xzf penflow_linux_x64_v6.tar.gz
cd bundle
./penflow
# 默认账号：admin / admin
```

KVM 前置依赖（使用真实 VM 功能时）：

```bash
sudo apt install libvirt-daemon-system virt-manager virt-viewer
sudo systemctl start libvirtd
sudo usermod -aG libvirt $USER
```

### Windows 构建

在 Windows 机器上安装 Flutter SDK + Visual Studio 2022（含 C++ 桌面开发组件），然后：

```cmd
git clone -b dev https://github.com/rakehellsx/penflow.git
cd penflow
flutter pub get
flutter build windows --release
```

VMware REST API 配置（使用真实 VM 功能时）：

```cmd
cd "C:\Program Files (x86)\VMware\VMware Workstation"
vmrest.exe -C
vmrest.exe
```

---

## 项目结构

```
lib/
├── main.dart
├── models/
│   ├── tool_model.dart
│   └── task_model.dart
├── data/
│   └── tools_data.dart
├── providers/
│   ├── workflow_provider.dart
│   ├── task_provider.dart
│   ├── vm_manager_provider.dart
│   └── auth_provider.dart
├── services/
│   ├── task_service.dart
│   ├── auth_service.dart
│   └── vm_backend.dart
├── screens/
│   ├── main_screen.dart
│   └── login_screen.dart
├── widgets/
│   ├── sidebar.dart
│   ├── top_bar.dart
│   ├── canvas_area.dart
│   ├── node_card.dart
│   ├── right_panel.dart
│   ├── vm_panel.dart
│   ├── create_vm_dialog.dart
│   ├── attack_chain_dialog.dart
│   └── change_password_dialog.dart
└── utils/
    └── app_theme.dart
examples/
├── full_domain_pentest.json
└── inject_workflow.py
```

---

## 版本历史

| 版本 | 主要更新 |
|------|----------|
| v6 | 左侧面板双Tab（任务管理/工具箱）、任务 SQLite 完整持久化、节点VM绑定持久化 |
| v5 | 节点"进入虚拟机"按钮对接 VMware/KVM 控制台 |
| v4 | 新建VM对话框、VM卡片操作菜单（关机/重启/挂起/删除） |
| v3 | SQLite 账号登录/修改密码、工具箱收缩、修复加载功能 |
| v2 | 黑/白皮肤切换 |
| v1 | 初始版本（工作流编辑器核心功能） |

---

PenFlow — 仅供授权渗透测试使用
