import 'package:flutter/material.dart';
import 'package:tutorium_frontend/models/flag_models.dart';
import 'package:tutorium_frontend/service/flag_service.dart';

/// Dialog for teacher to flag multiple learners
/// Production-ready with batch processing and progress tracking
class FlagLearnersDialog extends StatefulWidget {
  final List<LearnerToFlag> learners;

  const FlagLearnersDialog({super.key, required this.learners});

  @override
  State<FlagLearnersDialog> createState() => _FlagLearnersDialogState();
}

class _FlagLearnersDialogState extends State<FlagLearnersDialog> {
  String? selectedReason;
  String customReason = '';
  int flagCount = 1;
  bool isSubmitting = false;
  Set<int> selectedLearnerIds = {};

  @override
  void initState() {
    super.initState();
    // Select all by default
    selectedLearnerIds = widget.learners.map((l) => l.id).toSet();
  }

  Future<void> _submitFlags() async {
    // Validation
    if (selectedLearnerIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('โปรดเลือกนักเรียนอย่างน้อย 1 คน'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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

      final results = await FlagService.flagMultipleLearners(
        learnerIds: selectedLearnerIds.toList(),
        flagsToAdd: flagCount,
        reason: reason,
      );

      if (!mounted) return;

      final successCount = results.where((r) => r.success).length;
      final failCount = results.where((r) => !r.success).length;

      Navigator.of(context).pop(results); // Return results

      // Show summary
      if (failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Flag สำเร็จทั้งหมด $successCount คน'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️  Flag สำเร็จ $successCount คน, ล้มเหลว $failCount คน',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ เกิดข้อผิดพลาด: $e'),
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
              'Flag Learners',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'เลือกนักเรียนที่ต้องการ flag (${selectedLearnerIds.length}/${widget.learners.length})',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Learner selection
              const Text(
                'นักเรียน:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),

              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.learners.length,
                  itemBuilder: (context, index) {
                    final learner = widget.learners[index];
                    final isSelected = selectedLearnerIds.contains(learner.id);

                    return CheckboxListTile(
                      title: Text(
                        learner.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: learner.studentId != null
                          ? Text(
                              'ID: ${learner.studentId}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            )
                          : null,
                      value: isSelected,
                      onChanged: isSubmitting
                          ? null
                          : (checked) {
                              setState(() {
                                if (checked == true) {
                                  selectedLearnerIds.add(learner.id);
                                } else {
                                  selectedLearnerIds.remove(learner.id);
                                }
                              });
                            },
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),

              // Select/Deselect all buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () {
                            setState(() {
                              selectedLearnerIds = widget.learners
                                  .map((l) => l.id)
                                  .toSet();
                            });
                          },
                    icon: const Icon(Icons.check_box, size: 16),
                    label: const Text(
                      'เลือกทั้งหมด',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () {
                            setState(() {
                              selectedLearnerIds.clear();
                            });
                          },
                    icon: const Icon(Icons.check_box_outline_blank, size: 16),
                    label: const Text(
                      'ยกเลิกทั้งหมด',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Reason selection
              const Text(
                'เหตุผล:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),

              ...FlagReasons.learnerReasons.map((reason) {
                return RadioListTile<String>(
                  title: Text(reason, style: const TextStyle(fontSize: 13)),
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
                'จำนวน Flags ต่อคน:',
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
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton.icon(
          onPressed: isSubmitting ? null : _submitFlags,
          icon: isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.flag),
          label: Text(
            isSubmitting
                ? 'กำลังส่ง...'
                : 'Flag ${selectedLearnerIds.length} คน',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

/// Data model for learner to flag
class LearnerToFlag {
  final int id;
  final String name;
  final String? studentId;

  LearnerToFlag({required this.id, required this.name, this.studentId});
}
