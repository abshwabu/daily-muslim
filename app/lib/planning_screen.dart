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
    super.dispose();
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

    // If before Fajr, we are in the 'isha' period from yesterday
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

  void _showFocusDurationDialog(models.Task task) {
    final controller = TextEditingController(text: '25');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Focus Duration',
          style: GoogleFonts.manrope(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF31332E),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How many minutes would you like to focus on "${task.title}"?',
              style: GoogleFonts.manrope(color: const Color(0xFF5E6059)),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF31332E),
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '25',
                suffixText: 'min',
                suffixStyle: GoogleFonts.manrope(
                  color: const Color(0xFFB2B2AB),
                  fontWeight: FontWeight.bold,
                ),
                filled: true,
                fillColor: const Color(0xFFE3E3DB).withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: const Color(0xFF5E6059),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    int duration = int.tryParse(controller.text) ?? 25;
                    if (duration <= 0) duration = 25;
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => FocusModeScreen(
                          taskTitle: task.title,
                          durationMinutes: duration,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF546356),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    elevation: 0,
                  ),
                  child: Text(
                    'START',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
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

  Future<void> _handleRollover() async {
    final success = await _repository.rolloverTasks();
    if (success) {
      _fetchDayPlan(showLoading: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unfinished tasks rolled over to today.')),
        );
      }
    }
  }

  Future<void> _toggleTask(models.Task task) async {
    final newStatus = !(task.isCompleted ?? false);

    // 1. Instant optimistic update in memory
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

    // 2. Persist explicit target status to Hive repository
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
          'Are you sure you want to delete "${task.title}"?',
          style: GoogleFonts.manrope(color: const Color(0xFF5E6059)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: const Color(0xFF5E6059))),
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

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFFBF9F4);
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF546356)))
                    : RefreshIndicator(
                        onRefresh: _fetchDayPlan,
                        color: const Color(0xFF546356),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 48),
                              _buildIntentionSection(),
                              const SizedBox(height: 32),
                              _buildFocusCard(),
                              const SizedBox(height: 32),
                              _buildRolloverButton(),
                              const SizedBox(height: 64),
                              _buildTaskListHeader(),
                              const SizedBox(height: 32),
                               if (_dayPlan != null) ...[
                                 Builder(
                                   builder: (context) {
                                     final items = _buildTimelineItems();
                                     if (items.isEmpty) {
                                       return const SizedBox.shrink();
                                     }
                                     return Column(
                                       children: items.map((item) {
                                         if (item.type == _TimelineItemType.prayer) {
                                           return _buildPrayerMilestoneCard(item.prayerName!, item.prayerTimeStr);
                                         } else {
                                           return _buildTaskItem(item.task!);
                                         }
                                       }).toList(),
                                     );
                                   },
                                 ),
                               ],
                              const SizedBox(height: 48),
                              _buildPulseComponent(),
                              const SizedBox(height: 64),
                              _buildFooter(),
                              const SizedBox(height: 140),
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

  Future<void> _handleResetDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Load Default Sunnah Tasks',
          style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: const Color(0xFF31332E)),
        ),
        content: Text(
          'This will populate your day plan with Sunnah Rawatib prayers, Post-Salah Adhkar, Duha, Morning/Evening Adhkar, Fasting & Quran habits. Any task can be customized or deleted.',
          style: GoogleFonts.manrope(color: const Color(0xFF5E6059)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: GoogleFonts.manrope(fontWeight: FontWeight.w800, color: const Color(0xFF5E6059))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF546356),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            child: Text('LOAD TASKS', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repository.resetToDefaultTasks(_selectedDate);
      _fetchDayPlan(showLoading: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Default Sunnah & Adhkar tasks loaded.')),
        );
      }
    }
  }

  Widget _buildRolloverButton() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          TextButton.icon(
            onPressed: _handleRollover,
            icon: const Icon(Icons.history, size: 16, color: Color(0xFF546356)),
            label: Text(
              'ROLLOVER UNFINISHED',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: const Color(0xFF546356),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _handleResetDefaults,
            icon: const Icon(Icons.auto_awesome_outlined, size: 16, color: Color(0xFF546356)),
            label: Text(
              'LOAD SUNNAH DEFAULTS',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: const Color(0xFF546356),
              ),
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
          top: -100,
          right: -100,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                color: const Color(0xFF546356).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -50,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                color: const Color(0xFFEFEEE7).withOpacity(0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE3E3DB),
                    ),
                    child: const Icon(Icons.person_outline, color: Color(0xFF546356), size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SAKINAH',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      color: const Color(0xFF31332E),
                    ),
                  ),
                ],
              ),
              const Icon(Icons.settings_outlined, color: Color(0xFF31332E), size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntentionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "TODAY'S INTENTION",
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            color: const Color(0xFF5E6059),
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: GoogleFonts.manrope(
              fontSize: 40,
              fontWeight: FontWeight.w200,
              height: 1.1,
              color: const Color(0xFF31332E),
            ),
            children: [
              const TextSpan(text: 'Quiet the mind, find '),
              TextSpan(
                text: 'clarity',
                style: GoogleFonts.manrope(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const TextSpan(text: ' in the pause.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFocusCard() {
    final currentAnchor = _getCurrentAnchor();
    final anchors = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    final currentIndex = anchors.indexOf(currentAnchor);
    
    models.Task? actualFocusTask;
    String displayAnchor = currentAnchor;

    // 1. Look for focus in current anchor
    final tasksInCurrent = _dayPlan?.sections[currentAnchor] ?? [];
    for (var t in tasksInCurrent) {
      if (t.isHighPriority ?? false) {
        actualFocusTask = t;
        break;
      }
    }

    // 2. If not found, look for focus in future anchors for today
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

    final focusTask = actualFocusTask ?? models.Task(
      id: 0, 
      title: "No focus set for ${currentAnchor.toUpperCase()}", 
      prayerAnchor: currentAnchor, 
      dueDate: DateTime.now()
    );

    final bool isFutureFocus = actualFocusTask != null && displayAnchor != currentAnchor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF31332E).withOpacity(0.04),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -60,
                top: -60,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7E7D6).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.filter_vintage, color: Color(0xFF546356), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        isFutureFocus ? 'UPCOMING FOCUS (${displayAnchor.toUpperCase()})' : 'MAIN FOCUS',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                          color: const Color(0xFF546356),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    focusTask.title,
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      height: 1.3,
                      color: const Color(0xFF31332E),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildChip('Deep Work'),
                          const SizedBox(width: 8),
                          _buildChip(actualFocusTask != null ? 'Focus Mode' : 'Paced'),
                        ],
                      ),
                      _buildPrimaryButton(actualFocusTask != null ? (isFutureFocus ? 'Prepare' : 'Start Focus') : 'Add New', onPressed: () {
                        if (actualFocusTask != null) {
                          _showFocusDurationDialog(actualFocusTask);
                        } else {
                          _showAddTaskSheet();
                        }
                      }),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, {VoidCallback? onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          gradient: const LinearGradient(
            colors: [Color(0xFF546356), Color(0xFF48574A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF546356).withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEEE7),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF5E6059),
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
        onTaskCreated: (title, taskTime, isHighPriority) async {
          final task = await _repository.createTask(
            title,
            taskTime,
            isHighPriority: isHighPriority,
          );
          if (task != null) {
            _fetchDayPlan();
          }
        },
        onStartFocus: (title, taskTime) async {
          final task = await _repository.createTask(
            title,
            taskTime,
            isHighPriority: true,
          );
          if (task != null) {
            _fetchDayPlan();
            _showFocusDurationDialog(task);
          }
        },
      ),
    );
  }

  Widget _buildTaskListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Scheduled Tasks',
          style: GoogleFonts.manrope(
            fontSize: 22,
            fontWeight: FontWeight.w300,
            color: const Color(0xFF31332E),
          ),
        ),
        TextButton.icon(
          onPressed: _showAddTaskSheet,
          icon: const Icon(Icons.add, size: 18, color: Color(0xFF546356)),
          label: Text(
            'ADD NEW',
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: const Color(0xFF546356),
            ),
          ),
        ),
      ],
    );
  }

  String _formatPrayerTime(String? rawTime) {
    if (rawTime == null || rawTime.isEmpty) return '--:--';
    final match = RegExp(r"(\d{1,2}):(\d{1,2})").firstMatch(rawTime);
    if (match == null) return rawTime;
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final dt = DateTime(2026, 1, 1, hour, minute);
    return DateFormat('hh:mm a').format(dt);
  }

  List<_TimelineItem> _buildTimelineItems() {
    final List<_TimelineItem> items = [];
    final selectedDate = _selectedDate;

    if (_dayPlan?.prayerTimes != null) {
      final timesMap = _dayPlan!.prayerTimes;
      final prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

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

  Widget _buildPrayerMilestoneCard(String prayerName, String? rawPrayerTime) {
    final formattedPrayerTime = _formatPrayerTime(rawPrayerTime);
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isSunrise
            ? const Color(0xFFEBF4B3).withOpacity(0.35)
            : const Color(0xFF546356).withOpacity(0.08),
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
              Icon(icon, size: 20, color: isSunrise ? const Color(0xFF5C6330) : const Color(0xFF546356)),
              const SizedBox(width: 12),
              Text(
                prayerName.toUpperCase(),
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: isSunrise ? const Color(0xFF5C6330) : const Color(0xFF31332E),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSunrise ? const Color(0xFF5C6330) : const Color(0xFF546356),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              formattedPrayerTime,
              style: GoogleFonts.manrope(
                fontSize: 12,
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

  Widget _buildTaskItem(models.Task task) {
    // Determine icon based on category/title
    IconData? spiritualIcon;
    if (task.isTemplate ?? false) {
      if (task.category == 'Azkar') {
        spiritualIcon = Icons.auto_awesome_outlined;
      } else if (task.category == 'Sunnah') {
        spiritualIcon = Icons.mosque_outlined;
      } else if (task.category == 'Quran') {
        spiritualIcon = Icons.menu_book_outlined;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: task.isCompleted ?? false ? const Color(0xFFF5F4ED).withOpacity(0.5) : const Color(0xFFF5F4ED),
        borderRadius: BorderRadius.circular(20),
        border: task.isTemplate ?? false 
            ? Border.all(color: const Color(0xFF546356).withOpacity(0.1), width: 1)
            : (task.isHighPriority ?? false ? const Border(left: BorderSide(color: Color(0xFF5C6330), width: 4)) : null),
        boxShadow: task.isTemplate ?? false ? [
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ] : null,
      ),
      child: Row(
        children: [
          // 1. Independent Checkbox Tap Area
          InkWell(
            onTap: () => _toggleTask(task),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: task.isCompleted ?? false ? const Color(0xFF546356) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF546356).withOpacity(0.4),
                    width: 2.0,
                  ),
                ),
                child: task.isCompleted ?? false
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // 2. Independent Task Details Area (opens edit sheet)
          Expanded(
            child: InkWell(
              onTap: () => _showEditTaskSheet(task),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (spiritualIcon != null) ...[
                          Icon(spiritualIcon, size: 16, color: const Color(0xFF546356).withOpacity(0.6)),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            task.title,
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: task.isTemplate ?? false ? FontWeight.w600 : FontWeight.w500,
                              decoration: task.isCompleted ?? false ? TextDecoration.lineThrough : null,
                              color: task.isCompleted ?? false ? const Color(0xFF5E6059) : const Color(0xFF31332E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (task.isHighPriority ?? false) ...[
                          Text(
                            'PRIORITY HIGH',
                            style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: const Color(0xFF5C6330),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(width: 3, height: 3, decoration: const BoxDecoration(color: Color(0xFFB2B2AB), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                        ],
                        if (task.isTemplate ?? false)
                          Text(
                            '${task.category?.toUpperCase() ?? "HABIT"} • SYSTEM',
                            style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: const Color(0xFF546356).withOpacity(0.5),
                            ),
                          )
                        else
                          Text(
                            DateFormat('hh:mm a').format(task.dueDate),
                            style: GoogleFonts.manrope(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
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
          // 3. Popup Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF5E6059), size: 20),
            color: const Color(0xFFFBF9F4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (value) {
              if (value == 'edit') {
                _showEditTaskSheet(task);
              } else if (value == 'toggle') {
                _toggleTask(task);
              } else if (value == 'focus') {
                _showFocusDurationDialog(task);
              } else if (value == 'delete') {
                _deleteTask(task);
              }
            },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF546356)),
                          const SizedBox(width: 12),
                          Text('Edit Task', style: GoogleFonts.manrope(fontSize: 14, color: const Color(0xFF31332E))),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            task.isCompleted ?? false ? Icons.check_box_outline_blank : Icons.check_box_outlined,
                            size: 18,
                            color: const Color(0xFF546356),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            task.isCompleted ?? false ? 'Mark Uncompleted' : 'Mark Completed',
                            style: GoogleFonts.manrope(fontSize: 14, color: const Color(0xFF31332E)),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'focus',
                      child: Row(
                        children: [
                          const Icon(Icons.shutter_speed, size: 18, color: Color(0xFF546356)),
                          const SizedBox(width: 12),
                          Text('Start Focus', style: GoogleFonts.manrope(fontSize: 14, color: const Color(0xFF31332E))),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete_outline, size: 18, color: Color(0xFFA73B21)),
                          const SizedBox(width: 12),
                          Text('Delete Task', style: GoogleFonts.manrope(fontSize: 14, color: const Color(0xFFA73B21))),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
  }

  Widget _buildPulseComponent() {
    final nextPrayer = _dayPlan?.prayerTimes['Asr'] ?? '...';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFD7E7D6).withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF546356).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shutter_speed, color: Color(0xFF546356), size: 22),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEXT SACRED PAUSE',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: const Color(0xFF546356),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Asr Reflection at $nextPrayer',
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF475549),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Icon(Icons.chevron_right, color: const Color(0xFF546356).withOpacity(0.4)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: 160,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFD7E7D6), Color(0xFFEBF4B3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFBF9F4), Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      stops: [0.0, 0.6],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFooterLink('Privacy'),
            const SizedBox(width: 40),
            _buildFooterLink('Terms'),
            const SizedBox(width: 40),
            _buildFooterLink('Help'),
          ],
        ),
      ],
    );
  }

  Widget _buildFooterLink(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.0,
        color: const Color(0xFF5E6059),
      ),
    );
  }
}

class _AddTaskSheet extends StatefulWidget {
  final DateTime selectedDate;
  final Map<String, dynamic>? prayerTimes;
  final Function(String title, DateTime taskTime, bool isHighPriority) onTaskCreated;
  final Function(String title, DateTime taskTime)? onStartFocus;

  const _AddTaskSheet({
    required this.selectedDate,
    this.prayerTimes,
    required this.onTaskCreated,
    this.onStartFocus,
  });

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleController = TextEditingController();
  late TimeOfDay _selectedTime;
  bool _isHighPriority = false;
  late PrayerTimeValidationResult _validationResult;

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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF546356),
              onPrimary: Colors.white,
              onSurface: Color(0xFF31332E),
            ),
          ),
          child: child!,
        );
      },
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

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 32,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create New Task',
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFF31332E),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFFB2B2AB)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildLabel('TASK TITLE'),
              TextField(
                controller: _titleController,
                autofocus: true,
                style: GoogleFonts.manrope(fontSize: 18, color: const Color(0xFF31332E)),
                decoration: InputDecoration(
                  hintText: 'What needs to be done?',
                  hintStyle: GoogleFonts.manrope(color: const Color(0xFFB2B2AB)),
                  filled: true,
                  fillColor: const Color(0xFFE3E3DB).withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(20),
                ),
              ),
              const SizedBox(height: 24),
              _buildLabel('SCHEDULED TIME'),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F4ED),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF546356).withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: Color(0xFF546356), size: 22),
                          const SizedBox(width: 12),
                          Text(
                            formattedTimeStr,
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF31332E),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'CHANGE',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF546356),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_validationResult.isValid)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA73B21).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFA73B21), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cannot set task within 30 mins of ${_validationResult.prayerName} (${_validationResult.prayerTimeStr}). Sacred pause active.',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFA73B21),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7E7D6).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF546356), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Time outside the 30-min prayer buffer.',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF546356),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLabel('SET AS MAIN FOCUS'),
                  Switch(
                    value: _isHighPriority,
                    activeColor: const Color(0xFF546356),
                    onChanged: (val) => setState(() => _isHighPriority = val),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_validationResult.isValid && _titleController.text.trim().isNotEmpty)
                      ? () {
                          widget.onTaskCreated(
                            _titleController.text.trim(),
                            taskDateTime,
                            _isHighPriority,
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
                  child: Text(
                    'CREATE TASK',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.0,
          color: const Color(0xFF5E6059),
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
  late PrayerTimeValidationResult _validationResult;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _selectedTime = TimeOfDay.fromDateTime(widget.task.dueDate);
    _isHighPriority = widget.task.isHighPriority ?? false;
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF546356),
              onPrimary: Colors.white,
              onSurface: Color(0xFF31332E),
            ),
          ),
          child: child!,
        );
      },
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

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 32,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Task',
                    style: GoogleFonts.manrope(
                      fontSize: 24,
                      fontWeight: FontWeight.w300,
                      color: const Color(0xFF31332E),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFFB2B2AB)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildLabel('TASK TITLE'),
              TextField(
                controller: _titleController,
                autofocus: false,
                style: GoogleFonts.manrope(fontSize: 18, color: const Color(0xFF31332E)),
                decoration: InputDecoration(
                  hintText: 'What needs to be done?',
                  hintStyle: GoogleFonts.manrope(color: const Color(0xFFB2B2AB)),
                  filled: true,
                  fillColor: const Color(0xFFE3E3DB).withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(20),
                ),
              ),
              const SizedBox(height: 24),
              _buildLabel('SCHEDULED TIME'),
              InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F4ED),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF546356).withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: Color(0xFF546356), size: 22),
                          const SizedBox(width: 12),
                          Text(
                            formattedTimeStr,
                            style: GoogleFonts.manrope(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF31332E),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'CHANGE',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF546356),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_validationResult.isValid)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFA73B21).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFA73B21), size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cannot set task within 30 mins of ${_validationResult.prayerName} (${_validationResult.prayerTimeStr}). Sacred pause active.',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFA73B21),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7E7D6).withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF546356), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Time outside the 30-min prayer buffer.',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF546356),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLabel('SET AS MAIN FOCUS'),
                  Switch(
                    value: _isHighPriority,
                    activeColor: const Color(0xFF546356),
                    onChanged: (val) => setState(() => _isHighPriority = val),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
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
                        child: Text(
                          'DELETE',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 56,
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
                                  category: widget.task.category,
                                  isTemplate: widget.task.isTemplate,
                                );
                                widget.onTaskUpdated(updatedTask);
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
                        child: Text(
                          'SAVE CHANGES',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.0,
          color: const Color(0xFF5E6059),
        ),
      ),
    );
  }
}
