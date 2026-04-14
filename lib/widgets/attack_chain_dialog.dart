import 'package:flutter/material.dart';
import '../data/tools_data.dart';
import '../utils/app_theme.dart';

class AttackChainDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onChainSelected;

  const AttackChainDialog({super.key, required this.onChainSelected});

  @override
  State<AttackChainDialog> createState() => _AttackChainDialogState();
}

class _AttackChainDialogState extends State<AttackChainDialog> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: SizedBox(
        width: 700,
        height: 500,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  const Text('🔗', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  const Text('攻击链模板',
                    style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  const Text('选择预设攻击链快速开始',
                    style: TextStyle(color: AppColors.text3, fontSize: 11)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.text3, size: 18),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Chain list
            Expanded(
              child: Scrollbar(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: kAttackChains.length,
                  itemBuilder: (context, index) {
                    final chain = kAttackChains[index];
                    final isHovered = _hoveredIndex == index;
                    return MouseRegion(
                      onEnter: (_) => setState(() => _hoveredIndex = index),
                      onExit: (_) => setState(() => _hoveredIndex = null),
                      child: GestureDetector(
                        onTap: () => widget.onChainSelected(chain),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: isHovered ? AppColors.card : AppColors.bg,
                            border: Border.all(
                              color: isHovered ? AppColors.blue : AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(chain['icon'] as String,
                                    style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 10),
                                  Text(chain['name'] as String,
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    )),
                                  const Spacer(),
                                  _RiskBadge(risk: chain['risk'] as String),
                                  const SizedBox(width: 8),
                                  _NodeCountBadge(count: (chain['nodes'] as List).length),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(chain['desc'] as String,
                                style: const TextStyle(color: AppColors.text3, fontSize: 10)),
                              const SizedBox(height: 8),
                              // Tool tags
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: (chain['tools'] as List<String>).map((toolName) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      color: AppColors.blue.withOpacity(0.1),
                                      border: Border.all(color: AppColors.blue.withOpacity(0.3)),
                                    ),
                                    child: Text(toolName,
                                      style: const TextStyle(color: AppColors.blue, fontSize: 9)),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskBadge extends StatelessWidget {
  final String risk;
  const _RiskBadge({required this.risk});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (risk) {
      case 'critical': color = AppColors.riskCritical; break;
      case 'high': color = AppColors.riskHigh; break;
      case 'medium': color = AppColors.riskMedium; break;
      default: color = AppColors.riskLow;
    }

    final labels = {
      'critical': '极危',
      'high': '高危',
      'medium': '中危',
      'low': '低危',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: color.withOpacity(0.15),
      ),
      child: Text(labels[risk] ?? risk,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

class _NodeCountBadge extends StatelessWidget {
  final int count;
  const _NodeCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Text('$count 节点',
        style: const TextStyle(color: AppColors.text3, fontSize: 9)),
    );
  }
}
