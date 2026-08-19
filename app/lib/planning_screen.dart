import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'focus_mode_screen.dart';
import 'planning_repository.dart';
import 'prayer_service.dart';
import 'models.dart' as models;

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => PlanningScreenState();
}

class PlanningScreenState extends State<PlanningScreen> {
  late PlanningRepository _repository;
  models.DayPlan? _dayPlan;
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  Timer? _refreshTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initRepository();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initRepository() async {
    _repository = PlanningRepository();
    _fetchDayPlan();
  }

  Future<void> refreshData() async {
    _fetchDayPlan();
  }

  Future<void> _fetchDayPlan({bool showLoading = true}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final plan = await _repository.getDayPlan(_selectedDate);
      if (mounted) {
        setState(() {
          _dayPlan = plan;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        if (showLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to load plan. Check connection.')),
          );
        }
      }
    }
  }

  void _onDateSelected(DateTime date) {
    if (DateUtils.isSameDay(_selectedDate, date)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDate = date;
    });
    _fetchDayPlan();
  }

  String _getCurrentAnchor() {
    if (_dayPlan == null || _dayPlan!.prayerTimes.isEmpty) return 'fajr';

    final now = DateTime.now();
    final anchors = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    
    List<DateTime> prayerDateTimes = [];
    for (var name in prayers) {
      final timeStr = _dayPlan!.prayerTimes[name];
      if (timeStr == null) continue;
      
      final timeMatch = RegExp(r"(\d{1,2}):(\d{1,2})").firstMatch(timeStr);
      if (timeMatch == null) continue;
      
      final hour = int.parse(timeMatch.group(1)!);
      final minute = int.parse(timeMatch.group(2)!);
      prayerDateTimes.add(DateTime(now.year, now.month, now.day, hour, minute));
    }

    if (prayerDateTimes.length < 5) return 'fajr';

    if (now.isBefore(prayerDateTimes[0])) {
      return 'isha';
    }

    for (int i = prayerDateTimes.length - 1; i >= 0; i--) {
      if (now.isAfter(prayerDateTimes[i]) || now.isAtSameMomentAs(prayerDateTimes[i])) {
        return anchors[i];
      }
    }
    return 'fajr';
  }

  Future<void> _handleRollover() async {
    HapticFeedback.mediumImpact();
    final success = await _repository.rolloverTasks();
    if (success) {
      _fetchDayPlan(showLoading: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unfinished tasks rolled over to today.', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF546356),
          ),
        );
      }
    }
  }

  Future<void> _handleResetDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: Color(0xFF546356), size: 22),
            const SizedBox(width: 10),
            Text(
              'Load Sunnah Habits',
              style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: const Color(0xFF31332E)),
            ),
          ],
        ),
        content: Text(
          'Populate your day with Sunnah Rawatib prayers, Post-Salah Adhkar, Duha, Morning/Evening Adhkar, Fasting & Quran routines. You can edit or delete any task at any time.',
          style: GoogleFonts.manrope(fontSize: 14, color: const Color(0xFF5E6059), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: const Color(0xFF5E6059))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF546356),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('LOAD HABITS', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repository.resetToDefaultTasks(_selectedDate);
      _fetchDayPlan(showLoading: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Default Sunnah & Adhkar routines loaded.', style: GoogleFonts.manrope(fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF546356),
          ),
        );
      }
    }
  }

  Future<void> _toggleTask(models.Task task) async {
    HapticFeedback.lightImpact();
    final newStatus = !(task.isCompleted ?? false);

    setState(() {
      if (_dayPlan != null) {
        for (final section in _dayPlan!.sections.values) {
          final index = section.indexWhere((t) => 
            (task.id != null && t.id != null && t.id == task.id) || 
            (task.templateId != null && t.templateId != null && t.templateId == task.templateId) ||
            (t.title.trim().toLowerCase() == task.title.trim().toLowerCase())
          );
          
          if (index != -1) {
            final current = section[index];
            section[index] = models.Task(
              id: current.id,
              title: current.title,
              prayerAnchor: current.prayerAnchor,
              dueDate: current.dueDate,
              isCompleted: newStatus,
              isHighPriority: current.isHighPriority,
              templateId: current.templateId,
              description: current.description,
              category: current.category,
              isTemplate: current.isTemplate,
            );
            break;
          }
        }
      }
    });

    await _repository.toggleTask(task, targetDate: _selectedDate, forceCompleted: newStatus);
    _fetchDayPlan(showLoading: false);
  }

  Future<void> _deleteTask(models.Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Delete Task',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: const Color(0xFF31332E)),
        ),
        content: Text(
          'Remove "${task.title}" from your day plan?',
          style: GoogleFonts.manrope(color: const Color(0xFF5E6059)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: const Color(0xFF5E6059))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA73B21),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            child: Text('DELETE', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _repository.deleteTask(task, targetDate: _selectedDate);
      if (success) {
        _fetchDayPlan(showLoading: false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task deleted.')),
          );
        }
      }
    }
  }

  void _showFocusDurationDialog(models.Task task) {
    int selectedMinutes = 25;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF546356).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.timer_outlined, color: Color(0xFF546356), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SACRED FOCUS SESSION',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: const Color(0xFF546356),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                task.title,
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF31332E),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'SELECT DURATION',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: const Color(0xFF5E6059),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [15, 25, 45, 60].map((mins) {
                  final isSel = selectedMinutes == mins;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setModalState(() => selectedMinutes = mins);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF546356) : const Color(0xFFF5F4ED),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSel ? const Color(0xFF546356) : const Color(0xFFE3E3DB),
                        ),
                      ),
                      child: Text(
                        '${mins}m',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                          color: isSel ? Colors.white : const Color(0xFF5E6059),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => FocusModeScreen(
                          taskTitle: task.title,
                          durationMinutes: selectedMinutes,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF546356),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text(
                    'ENTER FOCUS MODE',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTaskSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddTaskSheet(
        selectedDate: _selectedDate,
        prayerTimes: _dayPlan?.prayerTimes,
        onTaskCreated: (title, taskTime, isHighPriority, category) async {
          final task = await _repository.createTask(
            title,
            taskTime,
            isHighPriority: isHighPriority,
            category: category,
          );
          if (task != null) {
            _fetchDayPlan();
          }
        },
      ),
    );
  }

  void _showEditTaskSheet(models.Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditTaskSheet(
        task: task,
        selectedDate: _selectedDate,
        prayerTimes: _dayPlan?.prayerTimes,
        onTaskUpdated: (updatedTask) async {
          final success = await _repository.updateTask(updatedTask, targetDate: _selectedDate);
          if (success) {
            _fetchDayPlan(showLoading: false);
          }
        },
        onTaskDeleted: (taskToDelete) async {
          final success = await _repository.deleteTask(taskToDelete, targetDate: _selectedDate);
          if (success) {
            _fetchDayPlan(showLoading: false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Task deleted.')),
              );
            }
          }
        },
      ),
    );
  }

  List<_TimelineItem> _buildTimelineItems() {
    final List<_TimelineItem> items = [];
    final selectedDate = _selectedDate;

    if (_dayPlan?.prayerTimes != null) {
      final timesMap = _dayPlan!.prayerTimes;
      final prayers = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

      for (final name in prayers) {
        final timeStr = timesMap[name]?.toString();
        final minutes = PrayerTimeValidation.parsePrayerMinutes(timeStr);
        if (minutes != null) {
          final hour = minutes ~/ 60;
          final minute = minutes % 60;
          final prayerDateTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            hour,
            minute,
          );
          items.add(_TimelineItem.prayer(
            time: prayerDateTime,
            prayerName: name,
            prayerTimeStr: timeStr,
          ));
        }
      }
    }

    if (_dayPlan?.sections != null) {
      final List<models.Task> allTasks = [];
      for (final taskList in _dayPlan!.sections.values) {
        for (final task in taskList) {
          allTasks.add(task);
        }
      }

      final Map<String, models.Task> uniqueTasksMap = {};
      for (int i = 0; i < allTasks.length; i++) {
        final task = allTasks[i];
        final key = task.id?.toString() ?? 'idx_${i}_${task.title}_${task.dueDate.millisecondsSinceEpoch}';
        uniqueTasksMap[key] = task;
      }

      for (final task in uniqueTasksMap.values) {
        items.add(_TimelineItem.task(
          time: task.dueDate,
          task: task,
        ));
      }
    }

    items.sort((a, b) {
      final cmp = a.time.compareTo(b.time);
      if (cmp != 0) return cmp;
      if (a.type == _TimelineItemType.prayer && b.type == _TimelineItemType.task) return -1;
      if (a.type == _TimelineItemType.task && b.type == _TimelineItemType.prayer) return 1;
      return 0;
    });

    return items;
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFFBF9F4);

    final allTasks = _dayPlan?.sections.values.expand((t) => t).toList() ?? [];
    final completedCount = allTasks.where((t) => t.isCompleted == true).length;
    final totalCount = allTasks.length;
    final progress = totalCount > 0 ? (completedCount / totalCount).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          _buildAmbientBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopAppBar(),
                _buildCalendarRibbon(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF546356)))
                      : RefreshIndicator(
                          onRefresh: _fetchDayPlan,
                          color: const Color(0xFF546356),
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Elegant Intention & Progress Banner
                                _buildIntentionBanner(completedCount, totalCount, progress),
                                const SizedBox(height: 24),

                                // 2. Sacred Main Focus Card
                                _buildSacredFocusHero(),
                                const SizedBox(height: 24),

                                // 3. Action Pills Strip
                                _buildActionControlStrip(),
                                const SizedBox(height: 32),

                                // 4. Sacred Timeline Header
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'SACRED TIMELINE',
                                          style: GoogleFonts.manrope(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.5,
                                            color: const Color(0xFF546356),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Prayers & Scheduled Tasks',
                                          style: GoogleFonts.manrope(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF31332E),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE3E3DB).withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$completedCount / $totalCount done',
                                        style: GoogleFonts.manrope(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF5E6059),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                // 5. Continuous Timeline View
                                if (_dayPlan != null)
                                  Builder(
                                    builder: (context) {
                                      final items = _buildTimelineItems();
                                      if (items.isEmpty) {
                                        return _buildEmptyTimelineState();
                                      }
                                      return Column(
                                        children: items.map((item) {
                                          if (item.type == _TimelineItemType.prayer) {
                                            return _buildPrayerMilestone(item.prayerName!, item.prayerTimeStr);
                                          } else {
                                            return _buildTaskCard(item.task!);
                                          }
                                        }).toList(),
                                      );
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTaskSheet,
        backgroundColor: const Color(0xFF546356),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          'NEW TASK',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildAmbientBackground() {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -80,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                color: const Color(0xFFD7E7D6).withOpacity(0.35),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 120,
          left: -100,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
            child: Container(
              width: 320,
              height: 320,
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
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.75),
        border: const Border(bottom: BorderSide(color: Color(0xFFE3E3DB), width: 0.5)),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAILY RHYTHMS',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: const Color(0xFF546356),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMMM yyyy').format(_selectedDate),
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF31332E),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (!isToday)
                    TextButton.icon(
                      onPressed: () => _onDateSelected(DateTime.now()),
                      icon: const Icon(Icons.today, size: 16, color: Color(0xFF546356)),
                      label: Text(
                        'TODAY',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF546356),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF546356).withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

  Widget _buildCalendarRibbon() {
    final now = DateTime.now();
    // 14 days ribbon (3 days before, 10 days ahead)
    final startDate = now.subtract(const Duration(days: 3));

    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        border: const Border(bottom: BorderSide(color: Color(0xFFE3E3DB), width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = startDate.add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          final isToday = DateUtils.isSameDay(date, now);

          return GestureDetector(
            onTap: () => _onDateSelected(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF546356) : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: isToday && !isSelected
                    ? Border.all(color: const Color(0xFF546356), width: 1.5)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('E').format(date).toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? const Color(0xFFD7E7D6) : const Color(0xFF5E6059),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d').format(date),
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : const Color(0xFF31332E),
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

  Widget _buildIntentionBanner(int completedCount, int totalCount, double progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF31332E).withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "SACRED INTENTION",
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: const Color(0xFF546356),
                ),
              ),
              Text(
                '${(progress * 100).toInt()}% Done',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF546356),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"Intentions shape actions. Move with purpose, anchor in remembrance."',
            style: GoogleFonts.newsreader(
              fontSize: 17,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF31332E),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE3E3DB),
              color: const Color(0xFF546356),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSacredFocusHero() {
    final currentAnchor = _getCurrentAnchor();
    final anchors = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    final currentIndex = anchors.indexOf(currentAnchor);

    models.Task? actualFocusTask;
    String displayAnchor = currentAnchor;

    final tasksInCurrent = _dayPlan?.sections[currentAnchor] ?? [];
    for (var t in tasksInCurrent) {
      if (t.isHighPriority ?? false) {
        actualFocusTask = t;
        break;
      }
    }

    if (actualFocusTask == null && _dayPlan != null) {
      for (int i = currentIndex + 1; i < anchors.length; i++) {
        final futureAnchor = anchors[i];
        final tasksInFuture = _dayPlan!.sections[futureAnchor] ?? [];
        for (var t in tasksInFuture) {
          if (t.isHighPriority ?? false) {
            actualFocusTask = t;
            displayAnchor = futureAnchor;
            break;
          }
        }
        if (actualFocusTask != null) break;
      }
    }

    final hasFocus = actualFocusTask != null;
    final focusTitle = hasFocus ? actualFocusTask.title : "No main focus set for ${currentAnchor.toUpperCase()}";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF546356),
            const Color(0xFF3E4E40),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF546356).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFFD7E7D6), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'SACRED FOCUS (${displayAnchor.toUpperCase()})',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: const Color(0xFFD7E7D6),
                    ),
                  ),
                ],
              ),
              if (hasFocus)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'High Priority',
                    style: GoogleFonts.manrope(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            focusTitle,
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                hasFocus ? 'Launch dedicated timer' : 'Set a high priority goal',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFFD7E7D6).withOpacity(0.8),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (actualFocusTask != null) {
                    _showFocusDurationDialog(actualFocusTask);
                  } else {
                    _showAddTaskSheet();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF546356),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                icon: Icon(hasFocus ? Icons.play_arrow_rounded : Icons.add, size: 18),
                label: Text(
                  hasFocus ? 'FOCUS' : 'ADD FOCUS',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionControlStrip() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildActionPill(
            icon: Icons.add_circle_outline,
            label: 'Add Task',
            onTap: _showAddTaskSheet,
            isPrimary: true,
          ),
          const SizedBox(width: 10),
          _buildActionPill(
            icon: Icons.auto_awesome_outlined,
            label: 'Sunnah Habits',
            onTap: _handleResetDefaults,
          ),
          const SizedBox(width: 10),
          _buildActionPill(
            icon: Icons.history,
            label: 'Rollover Unfinished',
            onTap: _handleRollover,
          ),
        ],
      ),
    );
  }

  Widget _buildActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF546356) : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isPrimary ? const Color(0xFF546356) : const Color(0xFFE3E3DB),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF31332E).withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isPrimary ? Colors.white : const Color(0xFF546356)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isPrimary ? Colors.white : const Color(0xFF31332E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerMilestone(String prayerName, String? rawPrayerTime) {
    String cleanTime = '--:--';
    if (rawPrayerTime != null && rawPrayerTime.isNotEmpty) {
      final match = RegExp(r"(\d{1,2}):(\d{1,2})").firstMatch(rawPrayerTime);
      if (match != null) {
        final hour = int.parse(match.group(1)!);
        final minute = int.parse(match.group(2)!);
        cleanTime = DateFormat('hh:mm a').format(DateTime(2026, 1, 1, hour, minute));
      } else {
        cleanTime = rawPrayerTime;
      }
    }

    IconData icon;
    switch (prayerName.toLowerCase()) {
      case 'fajr':
        icon = Icons.wb_twilight;
        break;
      case 'sunrise':
        icon = Icons.wb_sunny_outlined;
        break;
      case 'dhuhr':
        icon = Icons.light_mode;
        break;
      case 'asr':
        icon = Icons.wb_sunny;
        break;
      case 'maghrib':
        icon = Icons.wb_twilight;
        break;
      case 'isha':
      default:
        icon = Icons.bedtime;
        break;
    }

    final isSunrise = prayerName.toLowerCase() == 'sunrise';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: isSunrise
            ? const Color(0xFFEBF4B3).withOpacity(0.3)
            : const Color(0xFF546356).withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSunrise
              ? const Color(0xFF5C6330).withOpacity(0.2)
              : const Color(0xFF546356).withOpacity(0.12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (isSunrise ? const Color(0xFF5C6330) : const Color(0xFF546356)).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: isSunrise ? const Color(0xFF5C6330) : const Color(0xFF546356)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prayerName.toUpperCase(),
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: isSunrise ? const Color(0xFF5C6330) : const Color(0xFF31332E),
                    ),
                  ),
                  Text(
                    isSunrise ? 'Duha prayer window' : 'Sacred pause checkpoint',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF5E6059),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSunrise ? const Color(0xFF5C6330) : const Color(0xFF546356),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              cleanTime,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(models.Task task) {
    final isDone = task.isCompleted ?? false;
    final isPriority = task.isHighPriority ?? false;

    IconData? categoryIcon;
    Color categoryColor = const Color(0xFF546356);

    if (task.category == 'Azkar') {
      categoryIcon = Icons.auto_awesome_outlined;
      categoryColor = const Color(0xFF8B6B4A);
    } else if (task.category == 'Sunnah') {
      categoryIcon = Icons.mosque_outlined;
      categoryColor = const Color(0xFF546356);
    } else if (task.category == 'Quran') {
      categoryIcon = Icons.menu_book_outlined;
      categoryColor = const Color(0xFF4A6B82);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDone ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPriority
              ? const Color(0xFF546356).withOpacity(0.4)
              : Colors.white,
          width: isPriority ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF31332E).withOpacity(isDone ? 0.01 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEditTaskSheet(task),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Custom Checkbox
                GestureDetector(
                  onTap: () => _toggleTask(task),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isDone ? const Color(0xFF546356) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDone ? const Color(0xFF546356) : const Color(0xFFB2B2AB),
                        width: 1.8,
                      ),
                    ),
                    child: isDone
                        ? const Icon(Icons.check, size: 15, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Task Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: isDone ? FontWeight.normal : FontWeight.w600,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          color: isDone ? const Color(0xFF5E6059).withOpacity(0.6) : const Color(0xFF31332E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (task.category != null && task.category!.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: categoryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (categoryIcon != null) ...[
                                    Icon(categoryIcon, size: 10, color: categoryColor),
                                    const SizedBox(width: 3),
                                  ],
                                  Text(
                                    task.category!.toUpperCase(),
                                    style: GoogleFonts.manrope(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: categoryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            DateFormat('hh:mm a').format(task.dueDate),
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF5E6059),
                            ),
                          ),
                          if (isPriority) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFB58D3D)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Trailing Focus launcher
                IconButton(
                  onPressed: () => _showFocusDurationDialog(task),
                  icon: const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF546356)),
                  tooltip: 'Focus Mode',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyTimelineState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Icon(Icons.spa_outlined, color: Color(0xFF546356), size: 36),
          const SizedBox(height: 12),
          Text(
            'A Peaceful, Open Day',
            style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF31332E)),
          ),
          const SizedBox(height: 6),
          Text(
            'No tasks scheduled yet. Tap below to add a new task or load default Sunnah habits.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(fontSize: 12, color: const Color(0xFF5E6059), height: 1.3),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: _showAddTaskSheet,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF546356),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text('ADD TASK', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// CREATE TASK SHEET
// ----------------------------------------------------
class _AddTaskSheet extends StatefulWidget {
  final DateTime selectedDate;
  final Map<String, dynamic>? prayerTimes;
  final Function(String title, DateTime taskTime, bool isHighPriority, String? category) onTaskCreated;

  const _AddTaskSheet({
    required this.selectedDate,
    this.prayerTimes,
    required this.onTaskCreated,
  });

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleController = TextEditingController();
  late TimeOfDay _selectedTime;
  bool _isHighPriority = false;
  String _selectedCategory = 'General';
  late PrayerTimeValidationResult _validationResult;

  final List<String> _categories = ['General', 'Sunnah', 'Quran', 'Azkar', 'Deep Work', 'Personal'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
    _validateCurrentTime();
  }

  void _validateCurrentTime() {
    _validationResult = PrayerTimeValidation.validateTaskTime(
      _selectedTime.hour,
      _selectedTime.minute,
      widget.prayerTimes,
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF546356),
            onPrimary: Colors.white,
            onSurface: Color(0xFF31332E),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _validateCurrentTime();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskDateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final formattedTimeStr = DateFormat('hh:mm a').format(taskDateTime);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 28,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create Routine Task',
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF31332E),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF5E6059)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title input
            TextField(
              controller: _titleController,
              autofocus: true,
              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF31332E)),
              decoration: InputDecoration(
                hintText: 'e.g. Read Surah Al-Mulk, Review Goals',
                hintStyle: GoogleFonts.manrope(color: const Color(0xFFB2B2AB), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF5F4ED),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(18),
              ),
            ),
            const SizedBox(height: 18),

            // Category selector chips
            Text('CATEGORY', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: const Color(0xFF5E6059))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _categories.map((cat) {
                final isSel = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSel,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = cat);
                  },
                  selectedColor: const Color(0xFF546356),
                  backgroundColor: const Color(0xFFF5F4ED),
                  labelStyle: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? Colors.white : const Color(0xFF5E6059),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Time Picker
            Text('SCHEDULED TIME', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: const Color(0xFF5E6059))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F4ED),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3E3DB)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFF546356), size: 20),
                        const SizedBox(width: 10),
                        Text(
                          formattedTimeStr,
                          style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF31332E)),
                        ),
                      ],
                    ),
                    Text('CHANGE', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF546356))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Sacred Pause Validation
            if (!_validationResult.isValid)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF2F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFA73B21).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFA73B21), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Within 30m of ${_validationResult.prayerName} (${_validationResult.prayerTimeStr}). Sacred pause buffer active.',
                        style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFA73B21)),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),

            // High priority toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Set as Sacred Main Focus', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF31332E))),
              value: _isHighPriority,
              activeColor: const Color(0xFF546356),
              onChanged: (val) => setState(() => _isHighPriority = val),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (_validationResult.isValid && _titleController.text.trim().isNotEmpty)
                    ? () {
                        widget.onTaskCreated(
                          _titleController.text.trim(),
                          taskDateTime,
                          _isHighPriority,
                          _selectedCategory,
                        );
                        Navigator.pop(context);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF546356),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE3E3DB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  elevation: 0,
                ),
                child: Text('CREATE TASK', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// EDIT TASK SHEET
// ----------------------------------------------------
class _EditTaskSheet extends StatefulWidget {
  final models.Task task;
  final DateTime selectedDate;
  final Map<String, dynamic>? prayerTimes;
  final Function(models.Task updatedTask) onTaskUpdated;
  final Function(models.Task taskToDelete) onTaskDeleted;

  const _EditTaskSheet({
    required this.task,
    required this.selectedDate,
    this.prayerTimes,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
  });

  @override
  State<_EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends State<_EditTaskSheet> {
  late TextEditingController _titleController;
  late TimeOfDay _selectedTime;
  late bool _isHighPriority;
  late String _selectedCategory;
  late PrayerTimeValidationResult _validationResult;

  final List<String> _categories = ['General', 'Sunnah', 'Quran', 'Azkar', 'Deep Work', 'Personal'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _selectedTime = TimeOfDay.fromDateTime(widget.task.dueDate);
    _isHighPriority = widget.task.isHighPriority ?? false;
    _selectedCategory = widget.task.category ?? 'General';
    _validateCurrentTime();
  }

  void _validateCurrentTime() {
    _validationResult = PrayerTimeValidation.validateTaskTime(
      _selectedTime.hour,
      _selectedTime.minute,
      widget.prayerTimes,
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF546356),
            onPrimary: Colors.white,
            onSurface: Color(0xFF31332E),
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _validateCurrentTime();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskDateTime = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final formattedTimeStr = DateFormat('hh:mm a').format(taskDateTime);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 28,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Task',
                  style: GoogleFonts.manrope(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF31332E),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF5E6059)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title input
            TextField(
              controller: _titleController,
              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF31332E)),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF5F4ED),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(18),
              ),
            ),
            const SizedBox(height: 18),

            // Category selector chips
            Text('CATEGORY', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: const Color(0xFF5E6059))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _categories.map((cat) {
                final isSel = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSel,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = cat);
                  },
                  selectedColor: const Color(0xFF546356),
                  backgroundColor: const Color(0xFFF5F4ED),
                  labelStyle: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? Colors.white : const Color(0xFF5E6059),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Time Picker
            Text('SCHEDULED TIME', style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: const Color(0xFF5E6059))),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F4ED),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE3E3DB)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Color(0xFF546356), size: 20),
                        const SizedBox(width: 10),
                        Text(
                          formattedTimeStr,
                          style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF31332E)),
                        ),
                      ],
                    ),
                    Text('CHANGE', style: GoogleFonts.manrope(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF546356))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // High priority toggle
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Set as Sacred Main Focus', style: GoogleFonts.manrope(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF31332E))),
              value: _isHighPriority,
              activeColor: const Color(0xFF546356),
              onChanged: (val) => setState(() => _isHighPriority = val),
            ),
            const SizedBox(height: 24),

            // Actions (Delete & Save)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onTaskDeleted(widget.task);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFA73B21),
                        side: const BorderSide(color: Color(0xFFA73B21)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                      ),
                      child: Text('DELETE', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (_validationResult.isValid && _titleController.text.trim().isNotEmpty)
                          ? () {
                              final updatedTask = models.Task(
                                id: widget.task.id,
                                title: _titleController.text.trim(),
                                prayerAnchor: widget.task.prayerAnchor,
                                dueDate: taskDateTime,
                                isCompleted: widget.task.isCompleted,
                                isHighPriority: _isHighPriority,
                                templateId: widget.task.templateId,
                                description: widget.task.description,
                                category: _selectedCategory,
                                isTemplate: widget.task.isTemplate,
                              );
                              widget.onTaskUpdated(updatedTask);
                              Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF546356),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        elevation: 0,
                      ),
                      child: Text('SAVE CHANGES', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _TimelineItemType { prayer, task }

class _TimelineItem {
  final _TimelineItemType type;
  final DateTime time;
  final String? prayerName;
  final String? prayerTimeStr;
  final models.Task? task;

  _TimelineItem.prayer({
    required this.time,
    required this.prayerName,
    required this.prayerTimeStr,
  })  : type = _TimelineItemType.prayer,
        task = null;

  _TimelineItem.task({
    required this.time,
    required this.task,
  })  : type = _TimelineItemType.task,
        prayerName = null,
        prayerTimeStr = null;
}
