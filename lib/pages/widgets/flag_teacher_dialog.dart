import 'package:flutter/material.dart';
import 'package:tutorium_frontend/models/flag_models.dart';
import 'package:tutorium_frontend/service/flag_service.dart';

/// Dialog for learner to flag a teacher
/// Production-ready with validation and error handling
class FlagTeacherDialog extends StatefulWidget {
  final int teacherId;
  final String teacherName;

  const FlagTeacherDialog({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<FlagTeacherDialog> createState() => _FlagTeacherDialogState();
}

class _FlagTeacherDialogState extends State<FlagTeacherDialog> {
  String? selectedReason;
  String customReason = '';
  int flagCount = 1;
  bool isSubmitting = false;

  Future<void> _submitFlag() async {
    // Validation
    if (selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('โปรดเลือกเหตุผลในการ flag'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selectedReason == FlagReasons.other && customReason.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('โปรดระบุเหตุผลอื่นๆ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      final reason = selectedReason == FlagReasons.other
          ? customReason
          : selectedReason!;

      await FlagService.flagTeacher(
        teacherId: widget.teacherId,
        flagsToAdd: flagCount,
        reason: reason,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true); // Return success

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Flag teacher "${widget.teacherName}" สำเร็จ'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ไม่สามารถ flag ได้: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.flag, color: Colors.red.shade600),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Flag Teacher',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'กำลัง flag: ${widget.teacherName}',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Reason selection
            const Text(
              'เหตุผล:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),

            ...FlagReasons.teacherReasons.map((reason) {
              return RadioListTile<String>(
                title: Text(reason, style: const TextStyle(fontSize: 14)),
                value: reason,
                groupValue: selectedReason,
                onChanged: isSubmitting
                    ? null
                    : (value) {
                        setState(() => selectedReason = value);
                      },
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }),

            // Custom reason input
            if (selectedReason == FlagReasons.other) ...[
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  labelText: 'ระบุเหตุผลอื่นๆ',
                  border: const OutlineInputBorder(),
                  hintText: 'กรุณาระบุรายละเอียด...',
                  enabled: !isSubmitting,
                ),
                maxLines: 2,
                maxLength: 200,
                onChanged: (value) {
                  setState(() => customReason = value);
                },
              ),
            ],

            const SizedBox(height: 16),

            // Flag count
            const Text(
              'จำนวน Flags:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: isSubmitting || flagCount <= 1
                      ? null
                      : () {
                          setState(() => flagCount--);
                        },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$flagCount',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: isSubmitting || flagCount >= 5
                      ? null
                      : () {
                          setState(() => flagCount++);
                        },
                ),
                const Spacer(),
                Text(
                  'Max: 5',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton.icon(
          onPressed: isSubmitting ? null : _submitFlag,
          icon: isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.flag),
          label: Text(isSubmitting ? 'กำลังส่ง...' : 'ส่ง Flag'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
