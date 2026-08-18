import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuickStatsWidget extends StatelessWidget {
  final int completedPrayers;
  final int totalPrayers;
  final int completedTasks;
  final int totalTasks;
  final int dhikrCount;
  final String cityName;
  final VoidCallback? onPrayersTap;
  final VoidCallback? onTasksTap;
  final VoidCallback? onDhikrTap;
  final VoidCallback? onQiblaTap;

  const QuickStatsWidget({
    super.key,
    this.completedPrayers = 3,
    this.totalPrayers = 5,
    this.completedTasks = 4,
    this.totalTasks = 6,
    this.dhikrCount = 99,
    this.cityName = 'Addis Ababa',
    this.onPrayersTap,
    this.onTasksTap,
    this.onDhikrTap,
    this.onQiblaTap,
  });

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF31332E).withOpacity(0.03),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: iconColor),
                ),
                Icon(Icons.arrow_forward_ios, size: 10, color: const Color(0xFF5E6059).withOpacity(0.4)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF31332E),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5E6059),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.25,
      children: [
        _buildStatCard(
          icon: Icons.mosque_outlined,
          title: 'Prayers Done',
          value: '$completedPrayers / $totalPrayers',
          iconColor: const Color(0xFF546356),
          onTap: onPrayersTap,
        ),
        _buildStatCard(
          icon: Icons.check_circle_outline,
          title: 'Tasks Finished',
          value: '$completedTasks / $totalTasks',
          iconColor: const Color(0xFF4A6B82),
          onTap: onTasksTap,
        ),
        _buildStatCard(
          icon: Icons.fingerprint,
          title: 'Dhikr Counter',
          value: '$dhikrCount',
          iconColor: const Color(0xFF8B6B4A),
          onTap: onDhikrTap,
        ),
        _buildStatCard(
          icon: Icons.explore_outlined,
          title: cityName,
          value: 'Qibla',
          iconColor: const Color(0xFF9E574D),
          onTap: onQiblaTap,
        ),
      ],
    );
  }
}
