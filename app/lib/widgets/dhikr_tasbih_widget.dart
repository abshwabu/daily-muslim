import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class DhikrItem {
  final String title;
  final String arabic;
  final String meaning;
  final int defaultTarget;

  const DhikrItem({
    required this.title,
    required this.arabic,
    required this.meaning,
    this.defaultTarget = 33,
  });
}

class DhikrTasbihWidget extends StatefulWidget {
  final VoidCallback? onCompletedCycle;
  final Function(int prayerCount, int dailyTotalCount)? onCountChanged;
  final int initialPrayerCount;
  final int initialDailyCount;
  final String prayerName;

  const DhikrTasbihWidget({
    super.key,
    this.onCompletedCycle,
    this.onCountChanged,
    this.initialPrayerCount = 0,
    this.initialDailyCount = 0,
    this.prayerName = 'Dhuhr',
  });

  @override
  State<DhikrTasbihWidget> createState() => _DhikrTasbihWidgetState();
}

class _DhikrTasbihWidgetState extends State<DhikrTasbihWidget> with SingleTickerProviderStateMixin {
  late int _prayerCount;
  late int _dailyTotalCount;
  int _selectedPresetIndex = 0;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  final List<DhikrItem> _presets = const [
    DhikrItem(
      title: 'SUBHANALLAH',
      arabic: 'سُبْحَانَ اللَّهِ',
      meaning: 'Glory be to Allah',
      defaultTarget: 33,
    ),
    DhikrItem(
      title: 'ALHAMDULILLAH',
      arabic: 'الْحَمْدُ لِلَّهِ',
      meaning: 'All praise is due to Allah',
      defaultTarget: 33,
    ),
    DhikrItem(
      title: 'ALLAHU AKBAR',
      arabic: 'اللَّهُ أَكْبَرُ',
      meaning: 'Allah is the Greatest',
      defaultTarget: 33,
    ),
    DhikrItem(
      title: 'ASTAGHFIRULLAH',
      arabic: 'أَسْتَغْفِرُ اللَّهَ',
      meaning: 'I seek forgiveness from Allah',
      defaultTarget: 33,
    ),
    DhikrItem(
      title: 'LA ILAHA ILLA ALLAH',
      arabic: 'لَا إِلَهَ إِلَّا اللَّهُ',
      meaning: 'There is no god but Allah',
      defaultTarget: 100,
    ),
    DhikrItem(
      title: 'SALAWAT',
      arabic: 'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ',
      meaning: 'Peace and blessings upon the Prophet',
      defaultTarget: 100,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _prayerCount = widget.initialPrayerCount;
    _dailyTotalCount = widget.initialDailyCount;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.94,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = _animController;
  }

  @override
  void didUpdateWidget(covariant DhikrTasbihWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPrayerCount != widget.initialPrayerCount) {
      setState(() {
        _prayerCount = widget.initialPrayerCount;
      });
    }
    if (oldWidget.initialDailyCount != widget.initialDailyCount) {
      setState(() {
        _dailyTotalCount = widget.initialDailyCount;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _animController.reverse().then((_) => _animController.forward());

    setState(() {
      _prayerCount++;
      _dailyTotalCount++;

      final currentPreset = _presets[_selectedPresetIndex];
      if (_prayerCount >= currentPreset.defaultTarget) {
        _prayerCount = 0;
        _selectedPresetIndex = (_selectedPresetIndex + 1) % _presets.length;
        HapticFeedback.vibrate();
        widget.onCompletedCycle?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Completed ${currentPreset.title}! Next: ${_presets[_selectedPresetIndex].title}'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF546356),
          ),
        );
      }
    });

    widget.onCountChanged?.call(_prayerCount, _dailyTotalCount);
  }

  void _reset() {
    HapticFeedback.mediumImpact();
    setState(() {
      _prayerCount = 0;
    });
    widget.onCountChanged?.call(0, _dailyTotalCount);
  }

  void _selectPreset(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPresetIndex = index;
      _prayerCount = 0;
    });
    widget.onCountChanged?.call(0, _dailyTotalCount);
  }

  @override
  Widget build(BuildContext context) {
    final current = _presets[_selectedPresetIndex];
    final progress = (_prayerCount / current.defaultTarget).clamp(0.0, 1.0);
    final prayerLabel = widget.prayerName.isNotEmpty && widget.prayerName != '...'
        ? 'AFTER ${widget.prayerName.toUpperCase()}'
        : 'DAILY DHIKR';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF31332E).withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header row with prayer session badge & daily total indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF546356).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  prayerLabel,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: const Color(0xFF546356),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF4B3).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD0E185).withOpacity(0.5)),
                    ),
                    child: Text(
                      'Today: $_dailyTotalCount',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF435A22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.tune_outlined, size: 20, color: Color(0xFF5E6059)),
                    tooltip: 'Change Dhikr',
                    onSelected: _selectPreset,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    itemBuilder: (context) => _presets.asMap().entries.map((e) {
                      return PopupMenuItem<int>(
                        value: e.key,
                        child: Text(
                          e.value.title,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: e.key == _selectedPresetIndex ? FontWeight.bold : FontWeight.normal,
                            color: e.key == _selectedPresetIndex ? const Color(0xFF546356) : const Color(0xFF31332E),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  IconButton(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF5E6059)),
                    tooltip: 'Reset prayer counter',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Arabic Text & Meaning
          Text(
            current.arabic,
            textAlign: TextAlign.center,
            style: GoogleFonts.amiri(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF31332E),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            current.meaning,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF5E6059),
            ),
          ),
          const SizedBox(height: 24),

          // Main Tap Button with Circular Progress (resets every prayer)
          ScaleTransition(
            scale: _scaleAnimation,
            child: GestureDetector(
              onTap: _handleTap,
              child: SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Custom circular progress ring
                    CustomPaint(
                      size: const Size(140, 140),
                      painter: _TasbihProgressPainter(
                        progress: progress,
                        trackColor: const Color(0xFFE3E3DB),
                        progressColor: const Color(0xFF546356),
                      ),
                    ),
                    // Inner click surface
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF546356),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF546356).withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$_prayerCount',
                            style: GoogleFonts.manrope(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '/ ${current.defaultTarget}',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFD7E7D6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tap button to count • Resets each prayer',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF5E6059).withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _TasbihProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _TasbihProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc
    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TasbihProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
