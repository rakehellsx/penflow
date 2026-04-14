# PenFlow - 渗透测试工作流编辑器

基于 Flutter 开发的跨平台桌面客户端，完整还原 pentest_workflow.html 原型系统，支持 **Windows** 和 **Linux** 双平台运行。

## 功能特性

### 核心功能
- **可视化工作流编辑器**：拖拽式节点画布，支持缩放/平移/网格对齐
- **30+ 渗透工具节点**：涵盖代理搭建、内网探测、漏洞利用、凭据操作、横向移动、NTLM中继、域渗透、域控攻击 8 大类别
- **贝塞尔曲线连线**：可视化攻击路径，支持连线删除
- **攻击链模板**：内置 3 条预设攻击链（基础内网渗透、域渗透攻击、NTLM中继）

### 节点功能
- 每个节点支持选择目标 VM、绑定载荷文件
- 节点状态管理（空闲/运行中/完成/错误）
- 节点复制、删除操作

### 右侧面板
- **工具文档**：点击节点查看完整使用文档（含命令示例）
- **执行日志**：实时记录所有操作日志，支持清空
- **报告生成**：一键生成 Markdown 格式渗透测试报告

### 工具栏
- 保存/加载工作流（本地持久化）
- 导出 JSON 格式工作流
- 自动布局（网格排列）
- 适应视图（自动缩放到全部节点）
- 清空画布
- 加载攻击链

### VM 选择面板
- 底部滑出式面板
- 支持按 Linux/Windows/运行状态过滤
- 搜索虚拟机名称/IP/标签

## 构建说明

### 环境要求
- Flutter SDK 3.x+
- Linux: `clang`, `cmake`, `ninja-build`, `libgtk-3-dev`, `pkg-config`
- Windows: Visual Studio 2022 (含 C++ 桌面开发组件)

### Linux 构建
```bash
flutter pub get
flutter build linux --release
# 产物位于: build/linux/x64/release/bundle/
```

### Windows 构建
```bash
flutter pub get
flutter build windows --release
# 产物位于: build/windows/x64/runner/Release/
```

### 开发运行
```bash
flutter run -d linux    # Linux
flutter run -d windows  # Windows
```

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── models/
│   └── tool_model.dart          # 数据模型（节点、连线、VM、日志等）
├── data/
│   └── tools_data.dart          # 工具定义、VM数据、攻击链数据
├── providers/
│   └── workflow_provider.dart   # 全局状态管理
├── screens/
│   └── main_screen.dart         # 主屏幕
├── utils/
│   └── app_theme.dart           # 主题颜色配置
└── widgets/
    ├── top_bar.dart              # 顶部工具栏
    ├── sidebar.dart              # 左侧工具箱
    ├── canvas_area.dart          # 画布区域（核心）
    ├── connection_painter.dart   # 连线绘制
    ├── node_card.dart            # 节点卡片
    ├── right_panel.dart          # 右侧面板
    ├── vm_panel.dart             # VM选择面板
    └── attack_chain_dialog.dart  # 攻击链对话框
```

## 依赖包

| 包名 | 版本 | 用途 |
|------|------|------|
| provider | ^6.1.2 | 状态管理 |
| shared_preferences | ^2.3.2 | 本地持久化 |
| path_provider | ^2.1.4 | 文件路径 |
| uuid | ^4.5.1 | 唯一ID生成 |
| window_manager | ^0.4.3 | 窗口管理 |
| google_fonts | ^6.2.1 | 字体 |
| intl | ^0.19.0 | 国际化 |

## 快捷键

| 按键 | 功能 |
|------|------|
| Space + 拖拽 | 平移画布 |
| Ctrl + 滚轮 | 缩放画布 |
| Delete / Backspace | 删除选中节点 |
| Escape | 取消连线操作 |

---
*PenFlow v1.0.0 - 仅供授权渗透测试使用*
