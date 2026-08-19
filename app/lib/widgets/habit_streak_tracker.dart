import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HabitStreakTracker extends StatelessWidget {
  final int streakDays;
  final int completedTasks;
  final int totalTasks;
  final int completedPrayers;
  final int totalPrayers;
  final List<bool>? weekProgress;

  const HabitStreakTracker({
    super.key,
    this.streakDays = 1,
    this.completedTasks = 0,
    this.totalTasks = 0,
    this.completedPrayers = 0,
    this.totalPrayers = 5,
    this.weekProgress,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF546356);
    const textColor = Color(0xFF31332E);
    const mutedColor = Color(0xFF5E6059);

    final double totalRatio = totalTasks > 0 ? (completedTasks / totalTasks) : 0.0;
    final int percent = (totalRatio * 100).toInt();

    // 7 days of the current week
    final now = DateTime.now();
    final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final currentDayIndex = now.weekday - 1; // 0 for Monday, 6 for Sunday

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: textColor.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Streak count and title
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY RHYTHM & CONSISTENCY',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Weekly Rhythm',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF4B3).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD0E185).withOpacity(0.6)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, size: 15, color: Color(0xFF435A22)),
                    const SizedBox(width: 3),
                    Text(
                      '$streakDays Day Streak',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF435A22),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 7-day dots with responsive flex
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final isPast = index < currentDayIndex;
              final isToday = index == currentDayIndex;
              final bool isCompleted = weekProgress != null && index < weekProgress!.length
                  ? weekProgress![index]
                  : (isPast || (isToday && (percent >= 50 || completedPrayers >= 1)));

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? primaryColor
                            : isToday
                                ? const Color(0xFFD7E7D6)
                                : const Color(0xFFF5F4ED),
                        border: isToday
                            ? Border.all(color: primaryColor, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : isToday
                                ? Text(
                                    '$percent%',
                                    style: GoogleFonts.manrope(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: primaryColor,
                                    ),
                                  )
                                : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      weekDays[index],
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                        color: isToday ? primaryColor : mutedColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Progress overview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F4ED),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mosque_outlined, size: 18, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Prayers: $completedPrayers/$totalPrayers',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                Container(width: 1, height: 16, color: const Color(0xFFE3E3DB)),
                Row(
                  children: [
                    const Icon(Icons.task_alt, size: 18, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Tasks: $completedTasks/$totalTasks',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
