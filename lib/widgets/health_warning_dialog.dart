import 'package:flutter/material.dart';
import '../services/health_warning_service.dart';

class HealthWarningDialog extends StatefulWidget {
  final List<HealthWarning> warnings;
  final String mealTitle;
  final VoidCallback onContinue;
  final VoidCallback onCancel;

  const HealthWarningDialog({
    super.key,
    required this.warnings,
    required this.mealTitle,
    required this.onContinue,
    required this.onCancel,
  });

  @override
  State<HealthWarningDialog> createState() => _HealthWarningDialogState();
}

class _HealthWarningDialogState extends State<HealthWarningDialog> {
  bool _acknowledgeRisks = false;
  int _currentWarningIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentWarning = widget.warnings[_currentWarningIndex];
    final hasCriticalWarnings = widget.warnings.any((w) => w.type == 'critical');

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: currentWarning.color.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    currentWarning.icon,
                    color: currentWarning.color,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Health Warning',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: currentWarning.color,
                          ),
                        ),
                        Text(
                          'For: ${widget.mealTitle}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.warnings.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: currentWarning.color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentWarningIndex + 1}/${widget.warnings.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Warning Title
                    Text(
                      currentWarning.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Warning Message
                    Text(
                      currentWarning.message,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),

                    // Condition Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: currentWarning.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: currentWarning.color.withOpacity(0.5)),
                      ),
                      child: Text(
                        'Related to: ${currentWarning.condition}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: currentWarning.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Health Risks
                    if (currentWarning.risks.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.health_and_safety, color: Colors.red[600], size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Potential Health Risks:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...currentWarning.risks.map((risk) => Padding(
                        padding: const EdgeInsets.only(left: 28, bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(color: Colors.red[600])),
                            Expanded(child: Text(risk, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
                      const SizedBox(height: 16),
                    ],

                    // Alternatives
                    if (currentWarning.alternatives.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.lightbulb, color: Colors.green[600], size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Healthier Alternatives:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...currentWarning.alternatives.map((alternative) => Padding(
                        padding: const EdgeInsets.only(left: 28, bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• ', style: TextStyle(color: Colors.green[600])),
                            Expanded(child: Text(alternative, style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )),
                      const SizedBox(height: 16),
                    ],

                    // Navigation buttons for multiple warnings
                    if (widget.warnings.length > 1) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: _currentWarningIndex > 0
                                ? () => setState(() => _currentWarningIndex--)
                                : null,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Previous'),
                          ),
                          TextButton.icon(
                            onPressed: _currentWarningIndex < widget.warnings.length - 1
                                ? () => setState(() => _currentWarningIndex++)
                                : null,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Next'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Risk acknowledgment for critical warnings
                    if (hasCriticalWarnings) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: CheckboxListTile(
                          value: _acknowledgeRisks,
                          onChanged: (value) => setState(() => _acknowledgeRisks = value ?? false),
                          title: const Text(
                            'I understand the health risks and choose to proceed anyway',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Please consult your healthcare provider before consuming foods that conflict with your health conditions.',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: widget.onCancel,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey[400]!),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (hasCriticalWarnings && !_acknowledgeRisks) 
                          ? null 
                          : widget.onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasCriticalWarnings 
                            ? Colors.red[600] 
                            : Colors.orange[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        hasCriticalWarnings ? 'Proceed Anyway' : 'Continue',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Show health warning dialog
Future<bool?> showHealthWarningDialog({
  required BuildContext context,
  required List<HealthWarning> warnings,
  required String mealTitle,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => HealthWarningDialog(
      warnings: warnings,
      mealTitle: mealTitle,
      onContinue: () => Navigator.of(context).pop(true),
      onCancel: () => Navigator.of(context).pop(false),
    ),
  );
}
