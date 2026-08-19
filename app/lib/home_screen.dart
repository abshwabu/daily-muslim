import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'prayer_service.dart';
import 'planning_repository.dart';
import 'models.dart';
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
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _dhikrKey = GlobalKey();

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

  // Real Dynamic Functional State
  Set<String> _completedPrayers = {};
  int _completedTasksCount = 0;
  int _totalTasksCount = 0;
  int _streakDays = 1;
  List<bool> _weekProgress = [false, false, false, false, false, false, false];
  int _dailyTotalDhikrCount = 0;
  int _prayerDhikrCount = 0;
  String _lastDhikrPrayer = '';

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

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDateKey(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> refreshData() async {
    await Future.wait([
      _fetchUserData(),
      _fetchPrayerTimes(),
      _loadCompletedPrayers(),
      _loadTasksData(),
      _loadDhikrCount(),
    ]);
    await _calculateStreakAndWeek();
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
        _useLocalCalculatedPrayerTimes();
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      _useLocalCalculatedPrayerTimes();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _useLocalCalculatedPrayerTimes() {
    final cityName = _user?['city'] ?? 'Addis Ababa, Ethiopia';
    final cityLoc = PrayerService.findCity(cityName);
    final method = _user?['prayer_method'] ?? 3;
    final calcTimes = PrayerService.calculatePrayerTimes(
      latitude: cityLoc.latitude,
      longitude: cityLoc.longitude,
      date: DateTime.now(),
      methodId: method,
    );
    setState(() {
      _prayerTimes = calcTimes;
      _isLoading = false;
    });
    _calculateNextPrayer();
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

      // Check if prayer period transitioned -> reset per-prayer button counter
      if (_lastDhikrPrayer.isNotEmpty && _lastDhikrPrayer.toLowerCase() != prevName.toLowerCase()) {
        _prayerDhikrCount = 0;
        _lastDhikrPrayer = prevName;
        SharedPreferences.getInstance().then((prefs) {
          prefs.setInt('prayer_dhikr_count', 0);
          prefs.setString('last_dhikr_prayer', prevName);
        });
      } else if (_lastDhikrPrayer.isEmpty) {
        _lastDhikrPrayer = prevName;
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
        completedTasks: _completedTasksCount,
        totalTasks: _totalTasksCount,
      );
    }
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes} mins';
  }

  // --- Real Prayer Completion Tracking ---
  Future<void> _loadCompletedPrayers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = 'prayers_completed_${_formatDateKey(DateTime.now())}';
      final list = prefs.getStringList(todayKey) ?? [];
      setState(() {
        _completedPrayers = list.map((e) => e.toLowerCase()).toSet();
      });
    } catch (_) {}
  }

  Future<void> _togglePrayerCompletion(String prayerName) async {
    final nameKey = prayerName.toLowerCase();
    if (nameKey == 'sunrise') return;

    HapticFeedback.mediumImpact();
    final isCurrentlyCompleted = _completedPrayers.contains(nameKey);

    setState(() {
      if (isCurrentlyCompleted) {
        _completedPrayers.remove(nameKey);
      } else {
        _completedPrayers.add(nameKey);
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = 'prayers_completed_${_formatDateKey(DateTime.now())}';
      await prefs.setStringList(todayKey, _completedPrayers.toList());
    } catch (_) {}

    await _calculateStreakAndWeek();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !isCurrentlyCompleted
                ? 'Alhamdulillah! $prayerName marked as prayed.'
                : '$prayerName uncompleted.',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: !isCurrentlyCompleted ? const Color(0xFF546356) : const Color(0xFF5E6059),
        ),
      );
    }
  }

  // --- Real Tasks Data ---
  Future<void> _loadTasksData() async {
    try {
      final repo = PlanningRepository();
      final plan = await repo.getDayPlan(DateTime.now());
      if (plan != null) {
        final allTasks = plan.sections.values.expand((tasks) => tasks).toList();
        final completed = allTasks.where((t) => t.isCompleted == true).length;
        setState(() {
          _totalTasksCount = allTasks.length;
          _completedTasksCount = completed;
        });
        await WidgetService.syncTasksToWidget(allTasks);
      }
    } catch (_) {}
  }

  // --- Real Dhikr Tracking (Continuous whole-day + Per-prayer reset button) ---
  Future<void> _loadDhikrCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = 'daily_dhikr_${_formatDateKey(DateTime.now())}';
      final dailyCount = prefs.getInt(todayKey) ?? prefs.getInt('total_dhikr_count') ?? 0;
      final prayerCount = prefs.getInt('prayer_dhikr_count') ?? 0;
      final lastPrayer = prefs.getString('last_dhikr_prayer') ?? '';

      final currentPrayer = _prevPrayerName != '...' ? _prevPrayerName : 'Fajr';
      int activePrayerCount = prayerCount;

      if (lastPrayer.isNotEmpty && lastPrayer.toLowerCase() != currentPrayer.toLowerCase()) {
        // Reset the button count for the new prayer!
        activePrayerCount = 0;
        await prefs.setInt('prayer_dhikr_count', 0);
        await prefs.setString('last_dhikr_prayer', currentPrayer);
      }

      setState(() {
        _dailyTotalDhikrCount = dailyCount;
        _prayerDhikrCount = activePrayerCount;
        _lastDhikrPrayer = currentPrayer;
      });
    } catch (_) {}
  }

  Future<void> _onDhikrCountUpdated(int prayerCount, int dailyTotalCount) async {
    setState(() {
      _prayerDhikrCount = prayerCount;
      _dailyTotalDhikrCount = dailyTotalCount;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = 'daily_dhikr_${_formatDateKey(DateTime.now())}';
      await prefs.setInt(todayKey, dailyTotalCount);
      await prefs.setInt('total_dhikr_count', dailyTotalCount);
      await prefs.setInt('prayer_dhikr_count', prayerCount);
      await prefs.setString('last_dhikr_prayer', _prevPrayerName != '...' ? _prevPrayerName : 'Fajr');

      // Update home screen widget
      await WidgetService.updateDhikrWidget(
        title: 'SUBHANALLAH',
        meaning: 'Glory be to Allah',
        count: dailyTotalCount,
        target: 33,
      );
    } catch (_) {}
  }

  // --- Streak & Weekly Rhythm Calculation ---
  Future<void> _calculateStreakAndWeek() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final repo = PlanningRepository();
      final now = DateTime.now();

      // 1. Calculate 7-day week progress (Monday to Sunday of current week)
      final monday = now.subtract(Duration(days: now.weekday - 1));
      List<bool> weekProgress = [];

      for (int i = 0; i < 7; i++) {
        final day = DateTime(monday.year, monday.month, monday.day + i);
        final dateKey = _formatDateKey(day);
        final prayerList = prefs.getStringList('prayers_completed_$dateKey') ?? [];
        
        bool isDone = prayerList.isNotEmpty;
        if (!isDone) {
          final plan = await repo.getDayPlan(day);
          if (plan != null) {
            final tasks = plan.sections.values.expand((t) => t).toList();
            if (tasks.any((t) => t.isCompleted == true)) {
              isDone = true;
            }
          }
        }
        weekProgress.add(isDone);
      }

      // 2. Calculate consecutive day streak
      int streak = 0;
      for (int i = 0; i < 30; i++) {
        final day = DateTime(now.year, now.month, now.day - i);
        final dateKey = _formatDateKey(day);
        final prayerList = prefs.getStringList('prayers_completed_$dateKey') ?? [];
        bool dayActive = prayerList.isNotEmpty;

        if (!dayActive) {
          final plan = await repo.getDayPlan(day);
          if (plan != null) {
            final tasks = plan.sections.values.expand((t) => t).toList();
            if (tasks.any((t) => t.isCompleted == true)) {
              dayActive = true;
            }
          }
        }

        if (dayActive) {
          streak++;
        } else {
          // If today hasn't had activity yet, don't break previous streak
          if (i == 0) continue;
          break;
        }
      }

      if (streak == 0 && (_completedPrayers.isNotEmpty || _completedTasksCount > 0)) {
        streak = 1;
      }

      setState(() {
        _weekProgress = weekProgress;
        _streakDays = streak > 0 ? streak : 1;
      });
    } catch (_) {}
  }

  void _scrollToDhikr() {
    HapticFeedback.selectionClick();
    if (_dhikrKey.currentContext != null) {
      Scrollable.ensureVisible(
        _dhikrKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
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
    final Map<String, String> details = {
      'Fajr': '2 Rak\'ats Fard • 2 Rak\'ats Sunnah before',
      'Sunrise': 'Islamic sunrise • Duha prayer time starts 15 mins after',
      'Dhuhr': '4 Rak\'ats Fard • 4 Sunnah before, 2 Sunnah after',
      'Asr': '4 Rak\'ats Fard • 4 Sunnah before (optional)',
      'Maghrib': '3 Rak\'ats Fard • 2 Sunnah after',
      'Isha': '4 Rak\'ats Fard • 2 Sunnah after, 3 Witr',
    };

    final isSunrise = name.toLowerCase() == 'sunrise';
    final isPrayed = _completedPrayers.contains(name.toLowerCase());

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final currentlyPrayed = _completedPrayers.contains(name.toLowerCase());

          return Container(
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

                // Interactive Log / Mark Prayed Button
                if (!isSunrise) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _togglePrayerCompletion(name);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentlyPrayed ? const Color(0xFFE8EFE8) : const Color(0xFF546356),
                        foregroundColor: currentlyPrayed ? const Color(0xFF546356) : Colors.white,
                        elevation: currentlyPrayed ? 0 : 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                          side: currentlyPrayed ? const BorderSide(color: Color(0xFF546356), width: 1.5) : BorderSide.none,
                        ),
                      ),
                      icon: Icon(
                        currentlyPrayed ? Icons.check_circle : Icons.check_circle_outline,
                        size: 20,
                      ),
                      label: Text(
                        currentlyPrayed ? 'PRAYED ✓ (TAP TO UNMARK)' : 'MARK AS PRAYED',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF5E6059),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    ),
                    child: Text('CLOSE', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                ),
              ],
            ),
          );
        },
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
    final completedPrayersCount = _completedPrayers.where((p) => p != 'sunrise').length;

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
                        onRefresh: refreshData,
                        color: const Color(0xFF546356),
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 24),
                              
                              // 1. Next Prayer Pulse Card
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
                              const SizedBox(height: 28),

                              // 2. Prayer Timeline Schedule
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
                              const SizedBox(height: 14),
                              if (_prayerTimes != null)
                                PrayerTimelineWidget(
                                  prayerTimes: _prayerTimes!,
                                  nextPrayerName: _nextPrayerName,
                                  completedPrayers: _completedPrayers,
                                  onPrayerSelected: _showPrayerDetails,
                                  onPrayerToggle: _togglePrayerCompletion,
                                ),
                              const SizedBox(height: 28),

                              // 3. Quick Stats Grid Card
                              QuickStatsWidget(
                                completedPrayers: completedPrayersCount,
                                totalPrayers: 5,
                                completedTasks: _completedTasksCount,
                                totalTasks: _totalTasksCount,
                                dhikrCount: _dailyTotalDhikrCount,
                                cityName: _user?['city'] ?? 'Addis Ababa',
                                onPrayersTap: () => _showPrayerDetails(_nextPrayerName, _nextPrayerTime),
                                onTasksTap: () => widget.onNavigateTab?.call(1),
                                onDhikrTap: _scrollToDhikr,
                                onQiblaTap: _showQiblaSheet,
                              ),
                              const SizedBox(height: 28),

                              // 4. Habit & Consistency Tracker
                              HabitStreakTracker(
                                streakDays: _streakDays,
                                completedPrayers: completedPrayersCount,
                                totalPrayers: 5,
                                completedTasks: _completedTasksCount,
                                totalTasks: _totalTasksCount,
                                weekProgress: _weekProgress,
                              ),
                              const SizedBox(height: 28),

                              // 5. Interactive Dhikr Counter (Dual: per-prayer button + continuous whole-day)
                              Container(
                                key: _dhikrKey,
                                child: DhikrTasbihWidget(
                                  initialPrayerCount: _prayerDhikrCount,
                                  initialDailyCount: _dailyTotalDhikrCount,
                                  prayerName: _prevPrayerName,
                                  onCountChanged: _onDhikrCountUpdated,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // 6. Daily Reflection Ayah
                              const DailyReflectionCard(),
                              const SizedBox(height: 28),

                              // 7. Focus & Khushu Timer
                              FocusTimerCard(
                                onSessionCompleted: () async {
                                  await _loadTasksData();
                                  await _calculateStreakAndWeek();
                                },
                              ),
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
                fontSize: 26,
                fontWeight: FontWeight.w300,
                color: const Color(0xFF31332E),
                height: 1.2,
              ),
              children: [
                const TextSpan(text: 'Salam, '),
                TextSpan(
                  text: _user?['name'] ?? 'Muslim',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF546356)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
