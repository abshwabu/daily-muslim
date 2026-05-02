import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'focus_mode_screen.dart';
import 'api_service.dart';
import 'planning_repository.dart';
import 'models.dart' as models;

class PlanningScreen extends StatefulWidget {
  const PlanningScreen({super.key});

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen> {
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
    final token = await ApiService.getToken();
    print('Init Repository with token: ${token != null ? "Token present" : "Token NULL"}');
    
    if (token == null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
      return;
    }

    _repository = PlanningRepository(authToken: token);
    _fetchDayPlan();
  }

  Future<void> _fetchDayPlan() async {
    setState(() => _isLoading = true);
    try {
      print('Fetching plan for $_selectedDate');
      final plan = await _repository.getDayPlan(_selectedDate);
      print('Plan received: ${plan?.date}');
      print('Sections: ${plan?.sections.keys}');
      print('Fajr tasks: ${plan?.sections['fajr']?.length}');
      
      setState(() {
        _dayPlan = plan;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching plan: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load plan. Check connection.')),
        );
      }
    }
  }

  Future<void> _handleRollover() async {
    final success = await _repository.rolloverTasks();
    if (success) {
      _fetchDayPlan();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unfinished tasks rolled over to today.')),
        );
      }
    }
  }

  Future<void> _toggleTask(models.Task task) async {
    // Optimistic Update
    setState(() {
      final section = _dayPlan!.sections[task.prayerAnchor]!;
      final index = section.indexWhere((t) => 
        (t.id != null && t.id == task.id) || 
        (t.id == null && t.templateId != null && t.templateId == task.templateId)
      );
      
      if (index != -1) {
        final current = section[index];
        section[index] = models.Task(
          id: current.id,
          title: current.title,
          prayerAnchor: current.prayerAnchor,
          dueDate: current.dueDate,
          isCompleted: !(current.isCompleted ?? false),
          isHighPriority: current.isHighPriority,
          templateId: current.templateId,
          description: current.description,
          category: current.category,
          isTemplate: current.isTemplate,
        );
      }
    });

    final success = await _repository.toggleTask(task);
    if (!success) {
      // Revert if failed
      _fetchDayPlan();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update task. Reverting...')),
        );
      }
    }
  }

  void _onNavTap(String label) {
    if (label == 'Home') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
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
                                _buildPrayerSection('After Fajr', _dayPlan!.sections['fajr'] ?? []),
                                const SizedBox(height: 32),
                                _buildPrayerSection('After Dhuhr', _dayPlan!.sections['dhuhr'] ?? []),
                                const SizedBox(height: 32),
                                _buildPrayerSection('After Asr', _dayPlan!.sections['asr'] ?? []),
                                const SizedBox(height: 32),
                                _buildPrayerSection('After Maghrib', _dayPlan!.sections['maghrib'] ?? []),
                                const SizedBox(height: 32),
                                _buildPrayerSection('After Isha', _dayPlan!.sections['isha'] ?? []),
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
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildRolloverButton() {
    return Center(
      child: TextButton.icon(
        onPressed: _handleRollover,
        icon: const Icon(Icons.history, size: 16, color: Color(0xFF546356)),
        label: Text(
          'ROLLOVER UNFINISHED TASKS',
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: const Color(0xFF546356),
          ),
        ),
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
                      image: DecorationImage(
                        image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuAZFDUOr7S3ZJE-WwRXm_QC0kxr5ER8E2674nEo_VG5FzaKU2lqa4K302WA0HlF-Ck8IXnsv_G6PxLIHUJAZuwP3JN5tuTa1_sWQhFbQkgiir-vq7OyHJAF0__WMA8E6_rkkFKBH4nbcL6ocouKpqIM_JAEuqT1wxMI3w2-Hiqzw0gyq4DL28B01Q2aV9HsMNxmAL0hJa8-RCxpFgNnGlJ3myY0zN6bZNonRGt4jgDPCuE027jnXsJnSzy_5ILV6eEc4Y03UxcpBoU'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'THE SACRED PAUSE',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
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
        onTaskCreated: (title, anchor, isHighPriority) async {
          final task = await _repository.createTask(
            title,
            anchor,
            _selectedDate,
            isHighPriority: isHighPriority,
          );
          if (task != null) {
            _fetchDayPlan();
          }
        },
        onStartFocus: (title, anchor) async {
          final task = await _repository.createTask(
            title,
            anchor,
            _selectedDate,
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

  Widget _buildPrayerSection(String title, List<models.Task> tasks) {
    if (tasks.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: const Color(0xFF5E6059),
            ),
          ),
        ),
        ...tasks.map((task) => _buildTaskItem(task)).toList(),
      ],
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
      padding: const EdgeInsets.all(20),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _toggleTask(task),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: task.isCompleted ?? false ? const Color(0xFF546356) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF546356).withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                  child: task.isCompleted ?? false
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (spiritualIcon != null) ...[
                        Icon(spiritualIcon, size: 16, color: const Color(0xFF546356).withOpacity(0.6)),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        task.title,
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: task.isTemplate ?? false ? FontWeight.w600 : FontWeight.w500,
                          decoration: task.isCompleted ?? false ? TextDecoration.lineThrough : null,
                          color: task.isCompleted ?? false ? const Color(0xFF5E6059) : const Color(0xFF31332E),
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
                          '07:00 AM', // Placeholder for actual time if stored
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
            ],
          ),
          const Icon(Icons.more_vert, color: Color(0xFF5E6059), size: 20),
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
              ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Color(0xFFFBF9F4),
                  BlendMode.multiply,
                ),
                child: Opacity(
                  opacity: 0.4,
                  child: Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuDYr2mlaZ3e_ArpjGpLNaFXmWieM0jzgE2NOajeEabAIZs46LSYnAo6l_wiZWb1qfuhF0w9mna1zcDTJ2U-cggarTWlm1BaJ1c91M8Lzr_5z_iyMDL01MuU3KS5IuoILLNkBVL7DDX1bSHUt6cSzQ6MMN160KD41jYXS-MIHRDiZEC_sLdBbXdeqXOP1tVh8s5ZCjfKDaUwfFsSDvgFYhyL467FrrE2Sa_0niiQK6IWTMCgextGHpPgh4I0V2mw1QAt_ncSLqX8V3s',
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
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
                _buildNavItem(Icons.home_outlined, 'Home', false, () => _onNavTap('Home')),
                _buildNavItem(Icons.event_note, 'Plan', true, () => _onNavTap('Plan')),
                _buildNavItem(Icons.auto_stories_outlined, 'Journal', false, () => _onNavTap('Journal')),
                _buildNavItem(Icons.person_outline, 'Me', false, () => _onNavTap('Me')),
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
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 8,
                fontWeight: FontWeight.w800,
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

class _AddTaskSheet extends StatefulWidget {
  final Function(String, String, bool) onTaskCreated;
  final Function(String, String)? onStartFocus;

  const _AddTaskSheet({required this.onTaskCreated, this.onStartFocus});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleController = TextEditingController();
  String _selectedAnchor = 'fajr';
  bool _isHighPriority = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          color: Colors.white.withOpacity(0.85),
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
              const SizedBox(height: 32),
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
              _buildLabel('PRAYER ANCHOR'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].map((anchor) {
                    final isActive = _selectedAnchor == anchor;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedAnchor = anchor),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF546356) : const Color(0xFFF5F4ED),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            anchor.toUpperCase(),
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: isActive ? Colors.white : const Color(0xFF5E6059),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: Row(
                  children: [
                    Expanded(
                      flex: _isHighPriority ? 3 : 1,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_titleController.text.isNotEmpty) {
                            widget.onTaskCreated(
                              _titleController.text,
                              _selectedAnchor,
                              _isHighPriority,
                            );
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF546356),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          elevation: 0,
                        ),
                        child: Text(
                          _isHighPriority ? 'CREATE' : 'CREATE TASK',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                    ),
                    if (_isHighPriority) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (_titleController.text.isNotEmpty) {
                              widget.onStartFocus?.call(
                                _titleController.text,
                                _selectedAnchor,
                              );
                              Navigator.pop(context);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF546356), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                            foregroundColor: const Color(0xFF546356),
                            padding: const EdgeInsets.symmetric(vertical: 20),
                          ),
                          icon: const Icon(Icons.timer_outlined, size: 20),
                          label: Text(
                            'FOCUS',
                            style: GoogleFonts.manrope(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
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
      padding: const EdgeInsets.only(left: 4, bottom: 12),
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
