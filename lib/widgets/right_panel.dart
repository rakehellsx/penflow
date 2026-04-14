import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/tool_model.dart';
import '../providers/workflow_provider.dart';
import '../data/tools_data.dart';
import '../utils/app_theme.dart';

class RightPanel extends StatelessWidget {
  final int activeTab;
  final Function(int) onTabChange;

  const RightPanel(
      {super.key, required this.activeTab, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Container(
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(left: BorderSide(color: t.border)),
      ),
      child: Column(
        children: [
          _TabBar(activeTab: activeTab, onTabChange: onTabChange),
          Expanded(
            child: IndexedStack(
              index: activeTab,
              children: const [_DocsTab(), _LogsTab(), _ReportTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab Bar ───────────────────────────────────

class _TabBar extends StatelessWidget {
  final int activeTab;
  final Function(int) onTabChange;
  const _TabBar({required this.activeTab, required this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          _Tab(label: '📖 工具文档', index: 0, activeTab: activeTab, onTap: onTabChange),
          _Tab(label: '📋 执行日志', index: 1, activeTab: activeTab, onTap: onTabChange),
          _Tab(label: '📊 报告生成', index: 2, activeTab: activeTab, onTap: onTabChange),
        ],
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  final String label;
  final int index;
  final int activeTab;
  final Function(int) onTap;
  const _Tab(
      {required this.label,
      required this.index,
      required this.activeTab,
      required this.onTap});

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final isActive = widget.index == widget.activeTab;
    return Expanded(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit:  (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: () => widget.onTap(widget.index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isActive ? AppAccent.blue : Colors.transparent,
                  width: 2,
                ),
              ),
              color: _hovered && !isActive
                  ? t.card.withOpacity(0.5)
                  : Colors.transparent,
            ),
            child: Text(
              widget.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive ? AppAccent.blue : t.text3,
                fontSize: 10,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Docs Tab ──────────────────────────────────

class _DocsTab extends StatelessWidget {
  const _DocsTab();

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Consumer<WorkflowProvider>(
      builder: (context, provider, _) {
        final node = provider.selectedNode;
        if (node == null) return const _DocsPlaceholder();
        final tool = kTools.where((t) => t.id == node.toolId).firstOrNull;
        if (tool == null) return const _DocsPlaceholder();
        final cat = kCategories[tool.catId];

        return Column(
          children: [
            // Tool header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: cat?.color.withOpacity(0.2),
                    ),
                    alignment: Alignment.center,
                    child: Text(tool.icon,
                        style: const TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tool.name,
                            style: TextStyle(
                                color: t.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        Text(tool.desc,
                            style: TextStyle(
                                color: t.text3, fontSize: 10)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: _riskColor(tool.risk).withOpacity(0.15),
                    ),
                    child: Text(
                      _riskLabel(tool.risk),
                      style: TextStyle(
                          color: _riskColor(tool.risk),
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            // Meta info
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: Row(
                children: [
                  _MetaChip(label: tool.version),
                  const SizedBox(width: 6),
                  _MetaChip(label: tool.platform),
                  const Spacer(),
                  ...tool.tags.take(2).map((tag) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: t.card,
                            border: Border.all(color: t.border),
                          ),
                          child: Text(tag,
                              style: TextStyle(
                                  color: t.text3, fontSize: 9)),
                        ),
                      )),
                ],
              ),
            ),
            // Usage docs
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: _MarkdownText(text: tool.usage),
                ),
              ),
            ),
            // Node info footer
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.border)),
              ),
              child: Row(
                children: [
                  Text('当前节点',
                      style: TextStyle(color: t.text3, fontSize: 10)),
                  const Spacer(),
                  Text(tool.name,
                      style: TextStyle(color: t.text2, fontSize: 10)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DocsPlaceholder extends StatelessWidget {
  const _DocsPlaceholder();

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📖', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text('点击节点查看工具文档',
              style: TextStyle(color: t.text3, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: t.card,
        border: Border.all(color: t.border),
      ),
      child: Text(label,
          style: TextStyle(color: t.text2, fontSize: 9)),
    );
  }
}

class _MarkdownText extends StatelessWidget {
  final String text;
  const _MarkdownText({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final lines = text.split('\n');
    final widgets = <Widget>[];
    bool inCode = false;
    final codeLines = <String>[];

    for (final line in lines) {
      if (line.startsWith('```')) {
        if (inCode) {
          widgets.add(_CodeBlock(code: codeLines.join('\n')));
          codeLines.clear();
          inCode = false;
        } else {
          inCode = true;
        }
        continue;
      }
      if (inCode) {
        codeLines.add(line);
        continue;
      }

      if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(line.substring(3),
              style: TextStyle(
                  color: t.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ));
      } else if (line.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 3),
          child: Text(line.substring(4),
              style: TextStyle(
                  color: AppAccent.blue,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ));
      } else if (line.startsWith('- ✓ ') ||
          line.startsWith('- ⚠ ') ||
          line.startsWith('- ⚠')) {
        final isOk = line.contains('✓');
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text(line.substring(2),
              style: TextStyle(
                  color: isOk ? AppAccent.green : AppAccent.orange,
                  fontSize: 10)),
        ));
      } else if (line.startsWith('- ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 2),
          child: Text('• ${line.substring(2)}',
              style: TextStyle(color: t.text2, fontSize: 10)),
        ));
      } else if (line.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(line,
              style: TextStyle(color: t.text2, fontSize: 10)),
        ));
      } else {
        widgets.add(const SizedBox(height: 4));
      }
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;
  const _CodeBlock({required this.code});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: t.bg,
        border: Border.all(color: t.border),
      ),
      child: SelectableText(
        code,
        style: TextStyle(
          color: t.isDark ? AppAccent.cyan : const Color(0xFF0550AE),
          fontSize: 10,
          fontFamily: 'Consolas',
          height: 1.6,
        ),
      ),
    );
  }
}

// ── Logs Tab ──────────────────────────────────

class _LogsTab extends StatelessWidget {
  const _LogsTab();

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Consumer<WorkflowProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.border)),
              ),
              child: Row(
                children: [
                  Text('执行日志',
                      style:
                          TextStyle(color: t.text2, fontSize: 11)),
                  const Spacer(),
                  _SmallBtn(
                      label: '清空',
                      onTap: () => provider.clearLogs()),
                ],
              ),
            ),
            Expanded(
              child: provider.logs.isEmpty
                  ? Center(
                      child: Text('暂无日志',
                          style: TextStyle(
                              color: t.text3, fontSize: 11)),
                    )
                  : Scrollbar(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: provider.logs.length,
                        itemBuilder: (context, index) {
                          final log = provider.logs[index];
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: 3),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(_logIcon(log.type),
                                    style: const TextStyle(
                                        fontSize: 10)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    log.message,
                                    style: TextStyle(
                                        color: log.color,
                                        fontSize: 10,
                                        height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  String _logIcon(String type) {
    switch (type) {
      case 'success': return '✓';
      case 'warning': return '⚠';
      case 'error':   return '✗';
      default:        return '·';
    }
  }
}

class _SmallBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _SmallBtn({required this.label, required this.onTap});

  @override
  State<_SmallBtn> createState() => _SmallBtnState();
}

class _SmallBtnState extends State<_SmallBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
                color: _hovered ? AppAccent.red : t.border),
          ),
          child: Text(widget.label,
              style: TextStyle(
                  color: _hovered ? AppAccent.red : t.text3,
                  fontSize: 10)),
        ),
      ),
    );
  }
}

// ── Report Tab ────────────────────────────────

class _ReportTab extends StatefulWidget {
  const _ReportTab();

  @override
  State<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<_ReportTab> {
  final _domainController =
      TextEditingController(text: 'corp.local');

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Consumer<WorkflowProvider>(
      builder: (context, provider, _) {
        final nodeCount = provider.nodes.length;
        final connCount = provider.connections.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Report header card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: t.card,
                  border: Border.all(color: t.border),
                ),
                child: Row(
                  children: [
                    const Text('📊',
                        style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('报告生成',
                              style: TextStyle(
                                  color: t.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Text('渗透测试报告 · v1.0 · 通用',
                              style: TextStyle(
                                  color: t.text3, fontSize: 10)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: AppAccent.riskNone.withOpacity(0.15),
                      ),
                      child: Text('无风险',
                          style: TextStyle(
                              color: AppAccent.riskNone,
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Stats
              Row(
                children: [
                  _StatCard(
                      label: '节点数',
                      value: '$nodeCount',
                      color: AppAccent.blue),
                  const SizedBox(width: 8),
                  _StatCard(
                      label: '连线数',
                      value: '$connCount',
                      color: AppAccent.green),
                ],
              ),
              const SizedBox(height: 12),

              // Target domain
              Text('目标域',
                  style: TextStyle(color: t.text3, fontSize: 10)),
              const SizedBox(height: 4),
              TextField(
                controller: _domainController,
                onChanged: (v) => provider.setTargetDomain(v),
                style: TextStyle(color: t.text, fontSize: 11),
                decoration: const InputDecoration(
                  hintText: 'corp.local',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Report sections
              const _SectionTitle(title: '报告生成'),
              const _CheckItem(text: '收集信息', done: false),
              const _CheckItem(
                  text: '目标范围与授权文件', done: false, indent: 1),
              const _CheckItem(
                  text: '发现的漏洞列表', done: false, indent: 1),
              const _CheckItem(
                  text: '利用过程截图', done: false, indent: 1),
              const _CheckItem(
                  text: '获取的权限证明', done: false, indent: 1),
              const _CheckItem(
                  text: '修复建议', done: false, indent: 1),
              const SizedBox(height: 8),

              const _SectionTitle(title: '报告结构'),
              const _CheckItem(
                  text: '执行摘要 (管理层)', done: false),
              const _CheckItem(
                  text: '技术细节 (安全团队)', done: false),
              const _CheckItem(
                  text: '漏洞评级 (CVSS)', done: false),
              const _CheckItem(
                  text: '修复建议与优先级', done: true),
              const SizedBox(height: 12),

              // Generate button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      _generateReport(context, provider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppAccent.blue,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  child: const Text('生成渗透测试报告'),
                ),
              ),
              const SizedBox(height: 8),

              // Footer info
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: t.bg,
                  border: Border.all(color: t.border),
                ),
                child: Column(
                  children: [
                    _InfoRow(
                        label: '当前节点',
                        value: provider.selectedNode != null
                            ? (kTools
                                    .where((t) =>
                                        t.id ==
                                        provider
                                            .selectedNode!.toolId)
                                    .firstOrNull
                                    ?.name ??
                                '—')
                            : '—'),
                    _InfoRow(
                        label: '阶段',
                        value: provider.selectedNode != null
                            ? (kCategories[kTools
                                        .where((t) =>
                                            t.id ==
                                            provider.selectedNode!
                                                .toolId)
                                        .firstOrNull
                                        ?.catId ??
                                    '']
                                    ?.label ??
                                '—')
                            : '—'),
                    _InfoRow(
                        label: '目标域',
                        value: provider.targetDomain),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _generateReport(
      BuildContext context, WorkflowProvider provider) {
    final t = context.appTheme;
    final report = _buildReportContent(provider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.panel,
        title: Text('渗透测试报告',
            style: TextStyle(color: t.text, fontSize: 14)),
        content: SizedBox(
          width: 600,
          height: 500,
          child: Scrollbar(
            child: SingleChildScrollView(
              child: SelectableText(
                report,
                style: TextStyle(
                    color: t.text2,
                    fontSize: 11,
                    fontFamily: 'Consolas',
                    height: 1.6),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭',
                style: TextStyle(color: AppAccent.blue)),
          ),
        ],
      ),
    );
  }

  String _buildReportContent(WorkflowProvider provider) {
    final sb = StringBuffer();
    sb.writeln('# 渗透测试报告');
    sb.writeln('');
    sb.writeln('**目标域**: ${provider.targetDomain}');
    sb.writeln(
        '**生成时间**: ${DateTime.now().toString().substring(0, 19)}');
    sb.writeln('**工作流节点数**: ${provider.nodes.length}');
    sb.writeln('');
    sb.writeln('## 1. 执行摘要');
    sb.writeln('');
    sb.writeln(
        '本次渗透测试针对目标域 ${provider.targetDomain} 进行，');
    sb.writeln(
        '共使用 ${provider.nodes.length} 个工具节点，建立 ${provider.connections.length} 条攻击路径。');
    sb.writeln('');
    sb.writeln('## 2. 工具使用情况');
    sb.writeln('');
    for (final node in provider.nodes) {
      final tool =
          kTools.where((t) => t.id == node.toolId).firstOrNull;
      if (tool != null) {
        final cat = kCategories[tool.catId];
        sb.writeln(
            '- **${tool.name}** [${cat?.label ?? ''}] - 风险等级: ${_riskLabel(tool.risk)}');
        if (node.vmId != null) {
          final vm = kVirtualMachines
              .where((v) => v.id == node.vmId)
              .firstOrNull;
          if (vm != null) {
            sb.writeln('  - 目标主机: ${vm.name} (${vm.ip})');
          }
        }
        if (node.payload != null) {
          sb.writeln('  - 载荷文件: ${node.payload}');
        }
      }
    }
    sb.writeln('');
    sb.writeln('## 3. 攻击路径');
    sb.writeln('');
    for (final conn in provider.connections) {
      final fromNode = provider.nodes
          .where((n) => n.id == conn.fromNodeId)
          .firstOrNull;
      final toNode = provider.nodes
          .where((n) => n.id == conn.toNodeId)
          .firstOrNull;
      final fromTool = fromNode != null
          ? kTools
              .where((t) => t.id == fromNode.toolId)
              .firstOrNull
          : null;
      final toTool = toNode != null
          ? kTools
              .where((t) => t.id == toNode.toolId)
              .firstOrNull
          : null;
      if (fromTool != null && toTool != null) {
        sb.writeln('- ${fromTool.name} → ${toTool.name}');
      }
    }
    sb.writeln('');
    sb.writeln('## 4. 修复建议');
    sb.writeln('');
    sb.writeln('1. 及时修补已发现的漏洞，优先处理高危和极危漏洞');
    sb.writeln('2. 加强网络分段，限制横向移动');
    sb.writeln('3. 启用 SMB 签名，防止 NTLM 中继攻击');
    sb.writeln('4. 定期更换 krbtgt 账户密码');
    sb.writeln('5. 部署 EDR 解决方案，检测异常行为');
    return sb.toString();
  }
}

// ── Shared helper widgets ─────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: color.withOpacity(0.08),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            Text(label,
                style: TextStyle(color: t.text3, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(title,
          style: TextStyle(
              color: t.text2,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  final bool done;
  final int indent;
  const _CheckItem(
      {required this.text, required this.done, this.indent = 0});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(indent * 12.0, 0, 0, 3),
      child: Row(
        children: [
          Text(done ? '✓' : '·',
              style: TextStyle(
                  color: done ? AppAccent.green : t.text3,
                  fontSize: 10)),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  color: done ? AppAccent.green : t.text2,
                  fontSize: 10)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: TextStyle(color: t.text3, fontSize: 10)),
          Expanded(
            child: Text(value,
                style: TextStyle(color: t.text2, fontSize: 10),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

// ── Risk Level Helpers ────────────────────────

Color _riskColor(RiskLevel risk) {
  switch (risk) {
    case RiskLevel.critical: return AppAccent.riskCritical;
    case RiskLevel.high:     return AppAccent.riskHigh;
    case RiskLevel.medium:   return AppAccent.riskMedium;
    case RiskLevel.low:      return AppAccent.riskLow;
    case RiskLevel.none:     return AppAccent.riskNone;
  }
}

String _riskLabel(RiskLevel risk) {
  switch (risk) {
    case RiskLevel.critical: return '极危';
    case RiskLevel.high:     return '高危';
    case RiskLevel.medium:   return '中危';
    case RiskLevel.low:      return '低危';
    case RiskLevel.none:     return '无风险';
  }
}
