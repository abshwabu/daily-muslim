import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_service.dart';
import 'package:intl/intl.dart';
import 'planning_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _prayerTimes;
  bool _isLoading = true;
  String _nextPrayerName = '...';
  String _nextPrayerTime = '';
  String _prevPrayerName = '...';
  String _prevPrayerTime = '';
  Duration _timeUntilNext = Duration.zero;
  double _prayerProgress = 0.0;
  Timer? _timer;

  void _onNavTap(String label) {
    if (label == 'Plan') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PlanningScreen()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await ApiService.getToken();
    if (token == null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
      return;
    }
    _fetchPrayerTimes();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_prayerTimes != null) {
        _calculateNextPrayer();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPrayerTimes() async {
    try {
      final result = await ApiService.getPrayerTimes(city: 'Addis Ababa', method: 3);
      if (result['success']) {
        setState(() {
          _prayerTimes = result['data']['data']['timings'];
          _isLoading = false;
        });
        _calculateNextPrayer();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateNextPrayer() {
    if (_prayerTimes == null) return;

    final now = DateTime.now();
    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    
    DateTime? prevPrayerTime;
    DateTime? nextPrayerTime;
    String? nextName;

    for (int i = 0; i < prayers.length; i++) {
      final name = prayers[i];
      final timeStr = _prayerTimes![name];
      // Use regex to extract only HH:mm
      final timeMatch = RegExp(r"(\d{1,2}):(\d{1,2})").firstMatch(timeStr);
      if (timeMatch == null) continue;
      
      final hour = int.parse(timeMatch.group(1)!);
      final minute = int.parse(timeMatch.group(2)!);
      final pTime = DateTime(now.year, now.month, now.day, hour, minute);
      
      if (pTime.isAfter(now)) {
        nextPrayerTime = pTime;
        nextName = name;
        
        if (i == 0) {
          // Next is Fajr, previous was Isha yesterday
          final ishaTimeStr = _prayerTimes!['Isha'];
          final ishaMatch = RegExp(r"(\d{1,2}):(\d{1,2})").firstMatch(ishaTimeStr);
          if (ishaMatch != null) {
            final ishaHour = int.parse(ishaMatch.group(1)!);
            final ishaMinute = int.parse(ishaMatch.group(2)!);
            prevPrayerTime = DateTime(now.year, now.month, now.day - 1, ishaHour, ishaMinute);
          }
        } else {
          final prevName = prayers[i - 1];
          final prevTimeStr = _prayerTimes![prevName];
          final prevMatch = RegExp(r"(\d{1,2}):(\d{1,2})").firstMatch(prevTimeStr);
          if (prevMatch != null) {
            final prevHour = int.parse(prevMatch.group(1)!);
            final prevMinute = int.parse(prevMatch.group(2)!);
            prevPrayerTime = DateTime(now.year, now.month, now.day, prevHour, prevMinute);
          }
        }
        break;
      }
    }

    if (nextPrayerTime == null) {
      // All prayers passed today, next is Fajr tomorrow
      nextName = 'Fajr';
      final fajrTimeStr = _prayerTimes!['Fajr'];
      final fajrMatch = RegExp(r"(\d{1,2}):(\d{1,2})").firstMatch(fajrTimeStr);
      if (fajrMatch != null) {
        final fajrHour = int.parse(fajrMatch.group(1)!);
        final fajrMinute = int.parse(fajrMatch.group(2)!);
        nextPrayerTime = DateTime(now.year, now.month, now.day + 1, fajrHour, fajrMinute);
      }
      
      final ishaTimeStr = _prayerTimes!['Isha'];
      final ishaMatch = RegExp(r"(\d{1,2}):(\d{1,2})").firstMatch(ishaTimeStr);
      if (ishaMatch != null) {
        final ishaHour = int.parse(ishaMatch.group(1)!);
        final ishaMinute = int.parse(ishaMatch.group(2)!);
        prevPrayerTime = DateTime(now.year, now.month, now.day, ishaHour, ishaMinute);
      }
    }

    if (prevPrayerTime != null && nextPrayerTime != null) {
      final total = nextPrayerTime.difference(prevPrayerTime).inSeconds;
      final elapsed = now.difference(prevPrayerTime).inSeconds;
      
      // Determine previous prayer name
      String prevName = '';
      if (nextName == 'Fajr') {
        prevName = 'Isha';
      } else {
        int nextIndex = prayers.indexOf(nextName!);
        prevName = prayers[nextIndex - 1];
      }

      // Extract clean HH:mm for display
      String cleanTime(String raw) {
        final m = RegExp(r"(\d{1,2}):(\d{1,2})").firstMatch(raw);
        return m != null ? m.group(0)! : raw;
      }

      setState(() {
        _nextPrayerName = nextName!;
        _nextPrayerTime = cleanTime(_prayerTimes![nextName] ?? '');
        _prevPrayerName = prevName;
        _prevPrayerTime = cleanTime(_prayerTimes![prevName] ?? '');
        _timeUntilNext = nextPrayerTime!.difference(now);
        _prayerProgress = (elapsed / total).clamp(0.0, 1.0);
      });
    }
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes} mins';
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFFBF9F4);

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBody: true,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopAppBar(),
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF546356)))
                    : RefreshIndicator(
                        onRefresh: _fetchPrayerTimes,
                        color: const Color(0xFF546356),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 48),
                              _buildPrayerPulse(),
                              const SizedBox(height: 48),
                              _buildDailyRhythms(context),
                              const SizedBox(height: 48),
                              _buildReflectionGrid(),
                              const SizedBox(height: 120),
                            ],
                          ),
                        ),
                      ),
                ),
              ],
            ),
          ),
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned(
          top: 150,
          right: -50,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: const Color(0xFFD7E7D6).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 200,
          left: -100,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                color: const Color(0xFFEBF4B3).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF31332E).withOpacity(0.04),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE3E3DB),
                ),
                child: const Icon(Icons.person_outline, color: Color(0xFF546356)),
              ),
              Text(
                'THE SACRED PAUSE',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                  color: const Color(0xFF31332E),
                ),
              ),
              const Icon(Icons.settings_outlined, color: Color(0xFF31332E), size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final formatter = DateFormat('EEEE, MMMM d');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatter.format(now).toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: const Color(0xFF5E6059),
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: GoogleFonts.manrope(
              fontSize: 36,
              fontWeight: FontWeight.w200,
              height: 1.1,
              color: const Color(0xFF31332E),
            ),
            children: [
              const TextSpan(text: 'Welcome back,\n'),
              TextSpan(
                text: 'User',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF546356),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerPulse() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF31332E).withOpacity(0.06),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'NEXT PRAYER',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: const Color(0xFF5E6059),
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: GoogleFonts.manrope(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1.5,
                    color: const Color(0xFF546356),
                  ),
                  children: [
                    TextSpan(text: '$_nextPrayerName '),
                    TextSpan(
                      text: 'in ${_formatDuration(_timeUntilNext)}',
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        color: const Color(0xFF5E6059),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEEE7),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _prayerProgress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF546356),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_prevPrayerName.toUpperCase()} $_prevPrayerTime',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: const Color(0xFF5E6059),
                    ),
                  ),
                  Text(
                    '${_nextPrayerName.toUpperCase()} $_nextPrayerTime',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: const Color(0xFF5E6059),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyRhythms(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PRAYER TIME',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                color: const Color(0xFF31332E),
              ),
            ),
            Text(
              'View Qibla',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF546356),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPrayerCard('Fajr', _prayerTimes?['Fajr'] ?? '--:--', Icons.wb_twilight, _nextPrayerName == 'Fajr'),
                    const SizedBox(width: 12),
                    _buildPrayerCard('Dhuhr', _prayerTimes?['Dhuhr'] ?? '--:--', Icons.light_mode, _nextPrayerName == 'Dhuhr'),
                    const SizedBox(width: 12),
                    _buildPrayerCard('Asr', _prayerTimes?['Asr'] ?? '--:--', Icons.wb_sunny, _nextPrayerName == 'Asr'),
                    const SizedBox(width: 12),
                    _buildPrayerCard('Maghrib', _prayerTimes?['Maghrib'] ?? '--:--', Icons.wb_twilight, _nextPrayerName == 'Maghrib'),
                    const SizedBox(width: 12),
                    _buildPrayerCard('Isha', _prayerTimes?['Isha'] ?? '--:--', Icons.bedtime, _nextPrayerName == 'Isha'),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPrayerCard(String name, String time, IconData icon, bool isActive) {
    return Container(
      width: 112,
      height: 148,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? null : const Color(0xFFF5F4ED),
        gradient: isActive
            ? const LinearGradient(
                colors: [Color(0xFF546356), Color(0xFF48574A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF546356).withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            icon,
            color: isActive ? Colors.white : const Color(0xFF5E6059),
            size: 24,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: isActive ? Colors.white.withOpacity(0.8) : const Color(0xFF5E6059),
                ),
              ),
              Text(
                time,
                style: GoogleFonts.manrope(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : const Color(0xFF31332E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReflectionGrid() {
    return Column(
      children: [
        _buildBentoCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DAILY VERSE',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: const Color(0xFF5E6059),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"Verily, with every hardship comes ease."',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                        color: const Color(0xFF31332E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFFD7E7D6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.menu_book, color: Color(0xFF546356), size: 24),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSimpleBentoCard(
                icon: Icons.radio_button_checked,
                title: 'DHIKR',
                content: Column(
                  children: [
                    Text(
                      '33',
                      style: GoogleFonts.manrope(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF31332E),
                      ),
                    ),
                    Text(
                      'SUBHANALLAH',
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: const Color(0xFF5E6059),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSimpleBentoCard(
                icon: Icons.self_improvement,
                title: 'JOURNAL',
                content: Text(
                  'Write your morning reflection',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF5E6059),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSimpleBentoCard({
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4ED),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: const Color(0xFF546356), size: 20),
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: const Color(0xFF5E6059),
                ),
              ),
            ],
          ),
          const Spacer(),
          content,
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Positioned(
      bottom: 24,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF31332E).withOpacity(0.06),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(Icons.home, 'Home', true, () => _onNavTap('Home')),
                _buildNavItem(Icons.event_note, 'Plan', false, () => _onNavTap('Plan')),
                _buildNavItem(Icons.auto_stories, 'Journal', false, () => _onNavTap('Journal')),
                _buildNavItem(Icons.person, 'Me', false, () => _onNavTap('Me')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFD7E7D6).withOpacity(0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? const Color(0xFF354337) : const Color(0xFFB2B2AB),
              size: 24,
              fill: isActive ? 1.0 : 0.0,
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: isActive ? const Color(0xFF354337) : const Color(0xFFB2B2AB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
