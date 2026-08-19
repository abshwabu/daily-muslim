import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PrayerTimelineWidget extends StatelessWidget {
  final Map<String, dynamic> prayerTimes;
  final String nextPrayerName;
  final Set<String> completedPrayers;
  final Function(String name, String time)? onPrayerSelected;
  final Function(String name)? onPrayerToggle;

  const PrayerTimelineWidget({
    super.key,
    required this.prayerTimes,
    required this.nextPrayerName,
    this.completedPrayers = const {},
    this.onPrayerSelected,
    this.onPrayerToggle,
  });

  IconData _getPrayerIcon(String name) {
    switch (name.toLowerCase()) {
      case 'fajr':
        return Icons.wb_twilight;
      case 'sunrise':
        return Icons.wb_sunny_outlined;
      case 'dhuhr':
        return Icons.wb_sunny;
      case 'asr':
        return Icons.cloud_queue;
      case 'maghrib':
        return Icons.nights_stay_outlined;
      case 'isha':
        return Icons.bedtime;
      default:
        return Icons.access_time;
    }
  }

  String _cleanTime(dynamic raw) {
    if (raw == null) return '--:--';
    final match = RegExp(r"(\d{1,2}):(\d{1,2})").firstMatch(raw.toString());
    return match != null ? match.group(0)! : raw.toString();
  }

  @override
  Widget build(BuildContext context) {
    final prayers = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

    return SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: prayers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final name = prayers[index];
          final time = _cleanTime(prayerTimes[name]);
          final isNext = name.toLowerCase() == nextPrayerName.toLowerCase();
          final isCompleted = completedPrayers.contains(name.toLowerCase());
          final isSunrise = name.toLowerCase() == 'sunrise';

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onPrayerSelected?.call(name, time);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 100,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              decoration: BoxDecoration(
                color: isNext
                    ? const Color(0xFF546356)
                    : isCompleted
                        ? const Color(0xFFE8EFE8)
                        : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isNext
                      ? const Color(0xFF546356)
                      : isCompleted
                          ? const Color(0xFF546356).withOpacity(0.4)
                          : Colors.white,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isNext
                        ? const Color(0xFF546356).withOpacity(0.25)
                        : const Color(0xFF31332E).withOpacity(0.04),
                    blurRadius: isNext ? 16 : 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        _getPrayerIcon(name),
                        size: 22,
                        color: isNext
                            ? Colors.white
                            : isCompleted
                                ? const Color(0xFF546356)
                                : const Color(0xFF546356),
                      ),
                      Text(
                        name,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: isNext || isCompleted ? FontWeight.w700 : FontWeight.w600,
                          color: isNext
                              ? Colors.white
                              : isCompleted
                                  ? const Color(0xFF31332E)
                                  : const Color(0xFF31332E),
                        ),
                      ),
                      Text(
                        time,
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                          color: isNext
                              ? const Color(0xFFD7E7D6)
                              : isCompleted
                                  ? const Color(0xFF546356)
                                  : const Color(0xFF5E6059),
                        ),
                      ),
                    ],
                  ),
                  if (isCompleted && !isSunrise)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF546356),
                        ),
                        child: const Icon(Icons.check, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
