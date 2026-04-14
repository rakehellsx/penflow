#!/usr/bin/env python3
"""
PenFlow 工作流注入工具
将工作流 JSON 写入 shared_preferences 数据库，使系统"加载"按钮可直接读取。

shared_preferences 在 Linux 上存储路径:
  ~/.local/share/com.example.penflow/shared_preferences.json
  或
  ~/.local/share/penflow/shared_preferences.json
"""

import json
import os
import sys

WORKFLOW_FILE = os.path.join(os.path.dirname(__file__), "penflow_workflow_full.json")

# shared_preferences 在 Linux 上的可能路径
SP_PATHS = [
    os.path.expanduser("~/.local/share/com.example.penflow/shared_preferences.json"),
    os.path.expanduser("~/.local/share/penflow/shared_preferences.json"),
    os.path.expanduser("~/.local/share/com.penflow.penflow/shared_preferences.json"),
]

def find_or_create_sp_path():
    """找到已存在的 shared_preferences 文件，或创建新路径"""
    for path in SP_PATHS:
        if os.path.exists(path):
            print(f"[+] 找到已有数据库: {path}")
            return path
    # 使用第一个路径创建
    path = SP_PATHS[0]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    print(f"[+] 创建新数据库: {path}")
    return path

def inject():
    # 读取工作流 JSON
    with open(WORKFLOW_FILE, "r", encoding="utf-8") as f:
        workflow_data = json.load(f)

    # 构造 shared_preferences 格式（只保留 nodes/connections/targetDomain）
    sp_workflow = {
        "nodes": workflow_data["nodes"],
        "connections": workflow_data["connections"],
        "targetDomain": workflow_data["targetDomain"],
    }
    workflow_json_str = json.dumps(sp_workflow, ensure_ascii=False)

    # 找到 shared_preferences 文件
    sp_path = find_or_create_sp_path()

    # 读取已有数据（如果存在）
    if os.path.exists(sp_path):
        with open(sp_path, "r", encoding="utf-8") as f:
            try:
                sp_data = json.load(f)
            except json.JSONDecodeError:
                sp_data = {}
    else:
        sp_data = {}

    # 写入 workflow key
    sp_data["flutter.workflow"] = workflow_json_str

    # 保存
    with open(sp_path, "w", encoding="utf-8") as f:
        json.dump(sp_data, f, ensure_ascii=False, indent=2)

    print(f"[✓] 工作流已写入 shared_preferences")
    print(f"    节点数: {len(workflow_data['nodes'])}")
    print(f"    连线数: {len(workflow_data['connections'])}")
    print(f"    目标域: {workflow_data['targetDomain']}")
    print(f"\n[→] 现在打开 PenFlow，点击顶部工具栏「加载」按钮即可导入工作流")

if __name__ == "__main__":
    inject()
