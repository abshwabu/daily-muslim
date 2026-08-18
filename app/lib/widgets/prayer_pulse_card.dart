import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class PrayerPulseCard extends StatelessWidget {
  final String nextPrayerName;
  final String nextPrayerTime;
  final String prevPrayerName;
  final String prevPrayerTime;
  final Duration timeUntilNext;
  final double prayerProgress;
  final VoidCallback? onQiblaTap;
  final VoidCallback? onPrayerDetailsTap;
  final VoidCallback? onSettingsTap;

  const PrayerPulseCard({
    super.key,
    required this.nextPrayerName,
    required this.nextPrayerTime,
    required this.prevPrayerName,
    required this.prevPrayerTime,
    required this.timeUntilNext,
    required this.prayerProgress,
    this.onQiblaTap,
    this.onPrayerDetailsTap,
    this.onSettingsTap,
  });

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes} mins';
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF546356);
    const textColor = Color(0xFF31332E);
    const mutedTextColor = Color(0xFF5E6059);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: textColor.withOpacity(0.06),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top tag and actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7E7D6).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'NEXT PRAYER',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (onQiblaTap != null)
                          IconButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              onQiblaTap!();
                            },
                            icon: const Icon(Icons.explore_outlined, color: primaryColor, size: 22),
                            tooltip: 'Qibla Direction',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF5F4ED),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        const SizedBox(width: 8),
                        if (onPrayerDetailsTap != null)
                          IconButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              onPrayerDetailsTap!();
                            },
                            icon: const Icon(Icons.info_outline, color: primaryColor, size: 22),
                            tooltip: 'Prayer Information',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFFF5F4ED),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Main prayer time display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nextPrayerName.toUpperCase(),
                          style: GoogleFonts.manrope(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1.0,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 16, color: primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              'in ${_formatDuration(timeUntilNext)}',
                              style: GoogleFonts.manrope(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      nextPrayerTime,
                      style: GoogleFonts.manrope(
                        fontSize: 42,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -1.5,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Progress Bar
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            width: double.infinity,
                            color: const Color(0xFFE3E3DB),
                          ),
                          AnimatedFractionallySizedBox(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            widthFactor: prayerProgress.clamp(0.0, 1.0),
                            alignment: Alignment.centerLeft,
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF546356), Color(0xFF7A8D7D)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          prevPrayerName.isNotEmpty ? '$prevPrayerName $prevPrayerTime' : 'Previous',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: mutedTextColor,
                          ),
                        ),
                        Text(
                          '$nextPrayerName $nextPrayerTime',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
