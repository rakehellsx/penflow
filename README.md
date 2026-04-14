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

### Linux 下交叉编译 Windows 版本（MinGW-w64）

Flutter 官方不支持从 Linux 直接交叉编译 Windows 二进制，但可通过 **MinGW-w64 工具链** 绕过 Flutter CLI 直接调用 CMake 完成编译。以下步骤在 Ubuntu 22.04 / Debian 12 上验证通过。

#### 第一步：安装 MinGW-w64 交叉编译工具链

```bash
sudo apt update
sudo apt install -y \
  mingw-w64 \
  mingw-w64-tools \
  gcc-mingw-w64-x86-64 \
  g++-mingw-w64-x86-64 \
  binutils-mingw-w64-x86-64 \
  cmake ninja-build

# 验证安装
x86_64-w64-mingw32-gcc --version
```

#### 第二步：克隆项目并安装 Flutter 依赖

```bash
git clone -b dev https://github.com/rakehellsx/penflow.git
cd penflow

export PATH="$PATH:/path/to/flutter/bin"
flutter pub get
```

#### 第三步：编写 CMake MinGW 工具链文件

```bash
cat > /tmp/mingw-toolchain.cmake << 'EOF'
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

set(CMAKE_C_COMPILER   x86_64-w64-mingw32-gcc)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
set(CMAKE_RC_COMPILER  x86_64-w64-mingw32-windres)

set(CMAKE_FIND_ROOT_PATH /usr/x86_64-w64-mingw32)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF
```

#### 第四步：执行交叉编译

```bash
cd penflow/windows
mkdir -p build_cross && cd build_cross

cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=/tmp/mingw-toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -G "Unix Makefiles"

make -j$(nproc)
```

#### 第五步：收集运行时依赖 DLL

编译完成后，需将 MinGW 运行时 DLL 和 Flutter 引擎 DLL 一并打包，才能在目标 Windows 机器上运行：

```bash
mkdir -p /tmp/penflow_win_release

# 复制主程序
cp penflow.exe /tmp/penflow_win_release/

# 复制 MinGW 运行时 DLL（必须）
for dll in libgcc_s_seh-1.dll libstdc++-6.dll libwinpthread-1.dll; do
  find /usr/lib/gcc/x86_64-w64-mingw32 /usr/x86_64-w64-mingw32 \
    -name "$dll" 2>/dev/null | head -1 | xargs -I{} cp {} /tmp/penflow_win_release/
done

# 复制 Flutter Windows 引擎 DLL（从 Flutter SDK 缓存中获取）
FLUTTER_ENGINE_DIR=$(flutter --version 2>/dev/null | grep -o 'Engine.*' | head -1)
ENGINE_CACHE="$HOME/.pub-cache/hosted"
# flutter_windows.dll 由 flutter build windows 生成，位于 build/windows/x64/runner/Release/
# 交叉编译时需手动从 Flutter 引擎预编译包获取：
# https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/
cp flutter_windows.dll /tmp/penflow_win_release/ 2>/dev/null || \
  echo "请手动从 Flutter Windows 发布包中提取 flutter_windows.dll"

# 复制 sqlite3.dll（sqlite3_flutter_libs 提供）
find ~/.pub-cache -name "sqlite3.dll" 2>/dev/null | head -1 | \
  xargs -I{} cp {} /tmp/penflow_win_release/

# 打包
cd /tmp && zip -r penflow_windows_x64.zip penflow_win_release/
```

#### 注意事项

| 事项 | 说明 |
|------|------|
| Flutter 官方限制 | `flutter build windows` 命令本身仅支持在 Windows 宿主机运行，交叉编译需绕过 Flutter CLI 直接调用 CMake |
| flutter_windows.dll | Flutter 引擎的 Windows 版 DLL，需从 Flutter 官方 Windows 发布包中提取，或在 Windows 机器上构建一次后复制 |
| sqlite3.dll | 项目使用 `sqlite3_flutter_libs`，该包会在 Windows 构建时自动提供对应 DLL，交叉编译时需手动从 pub-cache 中查找 |
| 推荐替代方案 | 若有 CI/CD 环境，建议使用 **GitHub Actions** 的 `windows-latest` runner 完成 Windows 构建，更稳定可靠（见下方） |

#### 推荐方案：GitHub Actions 自动构建

在项目根目录创建 `.github/workflows/build.yml`：

```yaml
name: Build PenFlow

on:
  push:
    branches: [dev, main]

jobs:
  build-linux:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: sudo apt install -y clang cmake ninja-build libgtk-3-dev
      - run: flutter pub get
      - run: flutter build linux --release
      - uses: actions/upload-artifact@v4
        with:
          name: penflow-linux-x64
          path: build/linux/x64/release/bundle/

  build-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: flutter pub get
      - run: flutter build windows --release
      - uses: actions/upload-artifact@v4
        with:
          name: penflow-windows-x64
          path: build/windows/x64/runner/Release/
```

推送代码后，GitHub Actions 将自动在对应平台构建，产物可在 Actions 页面下载。

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
