import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models.dart';

class TaskCardWidget extends StatelessWidget {
  final Task task;
  final ValueChanged<bool?>? onToggleComplete;
  final VoidCallback? onTap;
  final VoidCallback? onStartFocus;
  final VoidCallback? onDelete;

  const TaskCardWidget({
    super.key,
    required this.task,
    this.onToggleComplete,
    this.onTap,
    this.onStartFocus,
    this.onDelete,
  });

  Color _getAnchorColor(String anchor) {
    switch (anchor.toLowerCase()) {
      case 'fajr':
        return const Color(0xFF4A6B82);
      case 'dhuhr':
        return const Color(0xFFC48B2C);
      case 'asr':
        return const Color(0xFF8B6B4A);
      case 'maghrib':
        return const Color(0xFF9E574D);
      case 'isha':
        return const Color(0xFF4E5B6E);
      default:
        return const Color(0xFF546356);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = task.isCompleted ?? false;
    final isHigh = task.isHighPriority ?? false;
    final anchorColor = _getAnchorColor(task.prayerAnchor);

    return Dismissible(
      key: Key('task_${task.id ?? task.title}_${task.dueDate}'),
      direction: onDelete != null ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFBA1A1A).withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      onDismissed: (_) => onDelete?.call(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFF0EFEA).withOpacity(0.6) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDone ? Colors.transparent : const Color(0xFFE3E3DB),
            width: 1,
          ),
          boxShadow: isDone
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF31332E).withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Custom Checkbox
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onToggleComplete?.call(!isDone);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? const Color(0xFF546356) : Colors.transparent,
                        border: Border.all(
                          color: isDone ? const Color(0xFF546356) : const Color(0xFFB5B7AF),
                          width: 2,
                        ),
                      ),
                      child: isDone
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Task details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: GoogleFonts.manrope(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDone ? const Color(0xFF9E9F99) : const Color(0xFF31332E),
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            decorationColor: const Color(0xFF9E9F99),
                          ),
                        ),
                        if (task.description != null && task.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              color: isDone ? const Color(0xFFB5B7AF) : const Color(0xFF5E6059),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),

                        // Tags row
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            // Prayer Anchor Chip
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: anchorColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                task.prayerAnchor.toUpperCase(),
                                style: GoogleFonts.manrope(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: anchorColor,
                                ),
                              ),
                            ),

                            // Category Chip
                            if (task.category != null && task.category!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F4ED),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  task.category!,
                                  style: GoogleFonts.manrope(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF5E6059),
                                  ),
                                ),
                              ),

                            // High Priority Chip
                            if (isHigh)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFBA1A1A).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.local_fire_department, size: 12, color: Color(0xFFBA1A1A)),
                                    const SizedBox(width: 2),
                                    Text(
                                      'PRIORITY',
                                      style: GoogleFonts.manrope(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFBA1A1A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Focus mode quick action
                  if (!isDone && onStartFocus != null)
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onStartFocus!();
                      },
                      icon: const Icon(Icons.timer_outlined, size: 20, color: Color(0xFF546356)),
                      tooltip: 'Start Focus Session',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFD7E7D6).withOpacity(0.5),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
