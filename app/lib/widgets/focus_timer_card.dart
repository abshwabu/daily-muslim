import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../focus_mode_screen.dart';

class FocusTimerCard extends StatefulWidget {
  final VoidCallback? onSessionCompleted;

  const FocusTimerCard({
    super.key,
    this.onSessionCompleted,
  });

  @override
  State<FocusTimerCard> createState() => _FocusTimerCardState();
}

class _FocusTimerCardState extends State<FocusTimerCard> {
  int _selectedMinutes = 25;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _selectDuration(int minutes) {
    if (_isRunning) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMinutes = minutes;
      _remainingSeconds = minutes * 60;
    });
  }

  void _toggleTimer() {
    HapticFeedback.mediumImpact();
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      setState(() => _isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          setState(() => _remainingSeconds--);
        } else {
          _timer?.cancel();
          setState(() {
            _isRunning = false;
            _remainingSeconds = _selectedMinutes * 60;
          });
          HapticFeedback.vibrate();
          widget.onSessionCompleted?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Alhamdulillah! Focus session completed.'),
              backgroundColor: Color(0xFF546356),
            ),
          );
        }
      });
    }
  }

  void _resetTimer() {
    HapticFeedback.selectionClick();
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _selectedMinutes * 60;
    });
  }

  String _formatTime() {
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF546356);
    const textColor = Color(0xFF31332E);
    const mutedColor = Color(0xFF5E6059);

    final totalSeconds = _selectedMinutes * 60;
    final progress = (1.0 - (_remainingSeconds / totalSeconds)).clamp(0.0, 1.0);

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
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7E7D6).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'FOCUS & KHUSHU',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: primaryColor,
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FocusModeScreen(
                        taskTitle: 'Deep Focus Session',
                        durationMinutes: _selectedMinutes,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.fullscreen, color: mutedColor, size: 20),
                tooltip: 'Fullscreen Focus Mode',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Presets row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [15, 25, 45].map((mins) {
              final isSelected = _selectedMinutes == mins;
              return GestureDetector(
                onTap: () => _selectDuration(mins),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryColor : const Color(0xFFF5F4ED),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${mins}m',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected ? Colors.white : mutedColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Timer Center Display
          Center(
            child: Text(
              _formatTime(),
              style: GoogleFonts.manrope(
                fontSize: 44,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Linear Progress
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE3E3DB),
              color: primaryColor,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 20),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isRunning || _remainingSeconds < totalSeconds)
                IconButton(
                  onPressed: _resetTimer,
                  icon: const Icon(Icons.replay, color: mutedColor),
                  tooltip: 'Reset',
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _toggleTimer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                icon: Icon(_isRunning ? Icons.pause : Icons.play_arrow, size: 18),
                label: Text(
                  _isRunning ? 'PAUSE' : 'START FOCUS',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w700, letterSpacing: 1.0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
