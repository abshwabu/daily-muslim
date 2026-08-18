import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';
import 'prayer_service.dart';
import 'journal_screen.dart';
import 'widgets/widgets.dart';
import 'services/widget_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(int index)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _prayerTimes;
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  String _nextPrayerName = '...';
  String _nextPrayerTime = '';
  String _prevPrayerName = '...';
  String _prevPrayerTime = '';
  Duration _timeUntilNext = Duration.zero;
  double _prayerProgress = 0.0;
  Timer? _timer;

  // Interactive Dhikr State
  int _dhikrCount = 0;
  int _dhikrTargetIndex = 0;
  final List<Map<String, dynamic>> _dhikrItems = [
    {'title': 'SUBHANALLAH', 'target': 33, 'meaning': 'Glory be to Allah'},
    {'title': 'ALHAMDULILLAH', 'target': 33, 'meaning': 'Praise be to Allah'},
    {'title': 'ALLAHU AKBAR', 'target': 33, 'meaning': 'Allah is the Greatest'},
    {'title': 'ASTAGHFIRULLAH', 'target': 33, 'meaning': 'I seek forgiveness from Allah'},
    {'title': 'LA ILAHA ILLA ALLAH', 'target': 33, 'meaning': 'There is no god but Allah'},
  ];

  // Interactive Daily Verse State
  int _verseIndex = 0;
  final List<Map<String, String>> _verses = [
    {
      'text': '"Verily, with every hardship comes ease."',
      'ref': 'Surah Ash-Sharh 94:6'
    },
    {
      'text': '"So remember Me; I will remember you."',
      'ref': 'Surah Al-Baqarah 2:152'
    },
    {
      'text': '"Call upon Me; I will respond to you."',
      'ref': 'Surah Ghafir 40:60'
    },
    {
      'text': '"Unquestionably, by the remembrance of Allah hearts find rest."',
      'ref': 'Surah Ar-Ra\'d 13:28'
    },
    {
      'text': '"And He found you lost and guided you."',
      'ref': 'Surah Ad-Duha 93:7'
    },
    {
      'text': '"Patience and prayer are your best helpers."',
      'ref': 'Surah Al-Baqarah 2:45'
    },
  ];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await refreshData();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_prayerTimes != null) {
        _calculateNextPrayer();
      }
    });
  }

  Future<void> refreshData() async {
    await _fetchUserData();
    await _fetchPrayerTimes();
  }

  Future<void> _fetchUserData() async {
    try {
      final result = await ApiService.getUser();
      if (result['success']) {
        setState(() {
          _user = result['data'];
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchPrayerTimes() async {
    try {
      final city = _user?['city'] ?? 'Addis Ababa, Ethiopia';
      final method = _user?['prayer_method'] ?? 3;
      final result = await ApiService.getPrayerTimes(city: city, method: method);
      if (result['success']) {
        setState(() {
          _prayerTimes = result['data']['data']['timings'];
          _isLoading = false;
        });
        _calculateNextPrayer();
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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
      final timeMatch = RegExp(r"(\d{1,2}):(\d{1,2})").firstMatch(timeStr);
      if (timeMatch == null) continue;
      
      final hour = int.parse(timeMatch.group(1)!);
      final minute = int.parse(timeMatch.group(2)!);
      final pTime = DateTime(now.year, now.month, now.day, hour, minute);
      
      if (pTime.isAfter(now)) {
        nextPrayerTime = pTime;
        nextName = name;
        
        if (i == 0) {
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
      
      String prevName = '';
      if (nextName == 'Fajr') {
        prevName = 'Isha';
      } else {
        int nextIndex = prayers.indexOf(nextName!);
        prevName = prayers[nextIndex - 1];
      }

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

      // Update Native OS Home Screen Widget
      WidgetService.updatePrayerWidget(
        nextPrayerName: _nextPrayerName,
        nextPrayerTime: _nextPrayerTime,
        timeUntilNext: 'in ${_formatDuration(_timeUntilNext)}',
        prevPrayerName: _prevPrayerName,
        prevPrayerTime: _prevPrayerTime,
        cityName: _user?['city'] ?? 'Addis Ababa',
      );
    }
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes} mins';
  }

  void _incrementDhikr() {
    HapticFeedback.lightImpact();
    setState(() {
      _dhikrCount++;
      final currentTarget = _dhikrItems[_dhikrTargetIndex]['target'] as int;
      if (_dhikrCount >= currentTarget) {
        _dhikrCount = 0;
        _dhikrTargetIndex = (_dhikrTargetIndex + 1) % _dhikrItems.length;
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Completed! Next: ${_dhikrItems[_dhikrTargetIndex]['title']}'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF546356),
          ),
        );
      }
    });
  }

  void _resetDhikr() {
    HapticFeedback.mediumImpact();
    setState(() {
      _dhikrCount = 0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Dhikr counter reset'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _nextVerse() {
    HapticFeedback.selectionClick();
    setState(() {
      _verseIndex = (_verseIndex + 1) % _verses.length;
    });
  }

  void _copyVerse() {
    final v = _verses[_verseIndex];
    Clipboard.setData(ClipboardData(text: '${v['text']} - ${v['ref']}'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Verse copied to clipboard'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFF546356),
      ),
    );
  }

  void _showQiblaSheet() {
    final cityName = _user?['city'] ?? 'Addis Ababa, Ethiopia';
    final cityLoc = PrayerService.findCity(cityName);
    final bearing = PrayerService.calculateQiblaBearing(cityLoc.latitude, cityLoc.longitude);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE3E3DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'QIBLA DIRECTION',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                color: const Color(0xFF5E6059),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              cityName,
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF31332E),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF5F4ED),
                border: Border.all(color: const Color(0xFF546356), width: 3),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: (bearing * 3.141592653589793) / 180.0,
                    child: const Icon(Icons.navigation, size: 64, color: Color(0xFF546356)),
                  ),
                  const Positioned(
                    top: 10,
                    child: Text('N', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF5E6059))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${bearing.toStringAsFixed(1)}° from North',
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF546356),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Point top of phone toward the arrow direction',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: const Color(0xFF5E6059),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showPrayerDetails(String name, String time) {
    Map<String, String> details = {
      'Fajr': '2 Rak\'ats Fard • 2 Rak\'ats Sunnah before',
      'Dhuhr': '4 Rak\'ats Fard • 4 Sunnah before, 2 Sunnah after',
      'Asr': '4 Rak\'ats Fard • 4 Sunnah before (optional)',
      'Maghrib': '3 Rak\'ats Fard • 2 Sunnah after',
      'Isha': '4 Rak\'ats Fard • 2 Sunnah after, 3 Witr',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E3DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name.toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF546356),
                  ),
                ),
                Text(
                  time,
                  style: GoogleFonts.manrope(
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    color: const Color(0xFF31332E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              details[name] ?? 'Daily Obligatory Prayer',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF5E6059),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF546356),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                ),
                child: Text('CLOSE', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editUserName() async {
    final nameController = TextEditingController(text: _user?['name'] ?? 'Muslim');
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Edit Name', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter your name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      await ApiService.updateSettings(name: newName);
      refreshData();
    }
  }

  void _showQuickSettings() {
    widget.onNavigateTab?.call(3); // Navigate to Me/Settings tab
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
                              const SizedBox(height: 28),
                              PrayerPulseCard(
                                nextPrayerName: _nextPrayerName,
                                nextPrayerTime: _nextPrayerTime,
                                prevPrayerName: _prevPrayerName,
                                prevPrayerTime: _prevPrayerTime,
                                timeUntilNext: _timeUntilNext,
                                prayerProgress: _prayerProgress,
                                onQiblaTap: _showQiblaSheet,
                                onPrayerDetailsTap: () => _showPrayerDetails(_nextPrayerName, _nextPrayerTime),
                              ),
                              const SizedBox(height: 32),
                              SectionHeader(
                                eyebrow: 'DAILY RHYTHMS',
                                title: 'Prayer Schedule',
                                subtitle: 'Location: ${_user?['city'] ?? 'Addis Ababa'}',
                                trailing: Row(
                                  children: [
                                    const Icon(Icons.explore_outlined, size: 16, color: Color(0xFF546356)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Qibla',
                                      style: GoogleFonts.manrope(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF546356),
                                      ),
                                    ),
                                  ],
                                ),
                                onTrailingTap: _showQiblaSheet,
                              ),
                              const SizedBox(height: 16),
                              if (_prayerTimes != null)
                                PrayerTimelineWidget(
                                  prayerTimes: _prayerTimes!,
                                  nextPrayerName: _nextPrayerName,
                                  onPrayerSelected: _showPrayerDetails,
                                ),
                              const SizedBox(height: 32),
                              QuickStatsWidget(
                                cityName: _user?['city'] ?? 'Addis Ababa',
                                onPrayersTap: () => _showPrayerDetails(_nextPrayerName, _nextPrayerTime),
                                onTasksTap: () => widget.onNavigateTab?.call(1),
                                onDhikrTap: () {},
                                onQiblaTap: _showQiblaSheet,
                              ),
                              const SizedBox(height: 32),
                              const HabitStreakTracker(
                                streakDays: 5,
                                completedPrayers: 3,
                                totalPrayers: 5,
                                completedTasks: 4,
                                totalTasks: 6,
                              ),
                              const SizedBox(height: 32),
                              const DhikrTasbihWidget(),
                              const SizedBox(height: 32),
                              const DailyReflectionCard(),
                              const SizedBox(height: 32),
                              const FocusTimerCard(),
                              const SizedBox(height: 120),
                            ],
                          ),
                        ),
                      ),
                ),
              ],
            ),
          ),
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
              GestureDetector(
                onTap: () => widget.onNavigateTab?.call(3),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE3E3DB),
                  ),
                  child: const Icon(Icons.person_outline, color: Color(0xFF546356)),
                ),
              ),
              GestureDetector(
                onTap: refreshData,
                child: Text(
                  'SAKINAH',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                    color: const Color(0xFF31332E),
                  ),
                ),
              ),
              IconButton(
                onPressed: _showQuickSettings,
                icon: const Icon(Icons.settings_outlined, color: Color(0xFF31332E), size: 24),
              ),
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
        GestureDetector(
          onTap: _editUserName,
          child: RichText(
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
                  text: '${_user?['name'] ?? 'User'} ✏️',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF546356),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerPulse() {
    return GestureDetector(
      onTap: () => _showPrayerDetails(_nextPrayerName, _nextPrayerTime),
      child: ClipRRect(
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
            GestureDetector(
              onTap: _showQiblaSheet,
              child: Row(
                children: [
                  const Icon(Icons.explore_outlined, size: 16, color: Color(0xFF546356)),
                  const SizedBox(width: 4),
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
    return GestureDetector(
      onTap: () => _showPrayerDetails(name, time),
      child: Container(
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
      ),
    );
  }

  Widget _buildReflectionGrid() {
    final v = _verses[_verseIndex];
    final dhikr = _dhikrItems[_dhikrTargetIndex];

    return Column(
      children: [
        GestureDetector(
          onTap: _nextVerse,
          onLongPress: _copyVerse,
          child: _buildBentoCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                          const SizedBox(width: 8),
                          Text(
                            '• TAP FOR NEXT',
                            style: GoogleFonts.manrope(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF546356),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        v['text']!,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                          color: const Color(0xFF31332E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        v['ref']!,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF546356),
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
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _incrementDhikr,
                onLongPress: _resetDhikr,
                child: _buildSimpleBentoCard(
                  icon: Icons.touch_app,
                  title: 'DHIKR TAP',
                  content: Column(
                    children: [
                      Text(
                        '$_dhikrCount / ${dhikr['target']}',
                        style: GoogleFonts.manrope(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF31332E),
                        ),
                      ),
                      Text(
                        dhikr['title'] as String,
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: const Color(0xFF546356),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => widget.onNavigateTab?.call(2),
                child: _buildSimpleBentoCard(
                  icon: Icons.edit_note,
                  title: 'JOURNAL',
                  content: Column(
                    children: [
                      const Icon(Icons.auto_stories, color: Color(0xFF546356), size: 24),
                      const SizedBox(height: 6),
                      Text(
                        'Write reflection',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5E6059),
                        ),
                      ),
                    ],
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
}
