import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'api_service.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<dynamic> _entries = [];
  String _currentPrompt = "What are you most grateful for in this quiet moment?";
  int _promptIndex = 0;
  bool _isLoading = true;
  final DateTime _today = DateTime.now();
  String _selectedFilter = 'All';

  final List<String> _curatedPrompts = [
    "What are you most grateful for in this quiet moment?",
    "How did you experience Allah's mercy or ease throughout your day?",
    "What is a personal prayer or du'a you want to pour your heart into today?",
    "Reflect on a difficulty you faced: what wisdom or strength did it bring?",
    "Which Ayah or Hadith brought peace to your heart recently, and why?",
    "How can you bring more khushu (mindfulness) into your next prayer?",
  ];

  final List<String> _categories = ['All', 'Gratitude', 'Sabr & Ease', 'Du\'a', 'Quran Reflection'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final promptResult = await ApiService.getJournalPrompt();
      if (promptResult['success'] && promptResult['data']?['data']?['prompt'] != null) {
        setState(() {
          _currentPrompt = promptResult['data']['data']['prompt'];
        });
      }

      final entriesResult = await ApiService.getJournalEntries();
      if (entriesResult['success']) {
        setState(() {
          _entries = entriesResult['data']['data'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error loading journal data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _cyclePrompt() {
    HapticFeedback.selectionClick();
    setState(() {
      _promptIndex = (_promptIndex + 1) % _curatedPrompts.length;
      _currentPrompt = _curatedPrompts[_promptIndex];
    });
  }

  void _openEntrySheet([Map<String, dynamic>? entry]) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => JournalEntrySheet(
        entry: entry,
        defaultPrompt: _currentPrompt,
        onSaved: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFFBF9F4);
    final todayStr = DateFormat('yyyy-MM-dd').format(_today);
    
    bool hasWrittenToday = false;
    Map<String, dynamic>? todayEntry;
    for (var e in _entries) {
      if (e is Map && e['date'] == todayStr) {
        hasWrittenToday = true;
        todayEntry = Map<String, dynamic>.from(e);
        break;
      }
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildTopAppBar(hasWrittenToday),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF546356)))
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: const Color(0xFF546356),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Header with date
                                _buildHeader(hasWrittenToday),
                                const SizedBox(height: 20),

                                // 2. Hero Prompt of the Day Card
                                _buildPromptCard(todayEntry),
                                const SizedBox(height: 28),

                                // 3. Filter category chips
                                _buildFilterChips(),
                                const SizedBox(height: 24),

                                // 4. History List
                                _buildHistorySection(),
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
        onPressed: () => _openEntrySheet(todayEntry),
        backgroundColor: const Color(0xFF546356),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: Icon(todayEntry != null ? Icons.edit_note : Icons.edit_outlined, size: 20),
        label: Text(
          todayEntry != null ? 'EDIT TODAY' : 'NEW ENTRY',
          style: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -80,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                color: const Color(0xFFD7E7D6).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 150,
          left: -80,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: const Color(0xFFEBF4B3).withOpacity(0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopAppBar(bool hasWrittenToday) {
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
                    'SACRED REFLECTIONS',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: const Color(0xFF546356),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Daily Journal',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF31332E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: hasWrittenToday ? const Color(0xFFD7E7D6) : const Color(0xFFF5F4ED),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasWrittenToday ? Icons.check_circle : Icons.edit_calendar,
                      size: 14,
                      color: const Color(0xFF546356),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasWrittenToday ? 'Reflected Today' : '${_entries.length} Entries',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF546356),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool hasWrittenToday) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('EEEE, MMMM d').format(_today).toUpperCase(),
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: const Color(0xFF5E6059),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Stillness & Gratitude',
          style: GoogleFonts.newsreader(
            fontSize: 28,
            fontWeight: FontWeight.w400,
            fontStyle: FontStyle.italic,
            color: const Color(0xFF31332E),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptCard(Map<String, dynamic>? todayEntry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF546356), Color(0xFF415243)],
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
                  const Icon(Icons.auto_awesome, color: Color(0xFFD7E7D6), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'PROMPT OF THE DAY',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: const Color(0xFFD7E7D6),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _cyclePrompt,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.refresh, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Change',
                        style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            todayEntry != null
                ? (todayEntry['prompt'] ?? _currentPrompt)
                : _currentPrompt,
            style: GoogleFonts.newsreader(
              fontSize: 20,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                todayEntry != null ? 'Entry saved for today' : 'Take a deep breath and write',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: const Color(0xFFD7E7D6).withOpacity(0.8),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openEntrySheet(todayEntry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF546356),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                icon: Icon(todayEntry != null ? Icons.visibility_outlined : Icons.edit_outlined, size: 16),
                label: Text(
                  todayEntry != null ? 'VIEW' : 'WRITE',
                  style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _categories.map((cat) {
          final isSel = _selectedFilter == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSel,
              onSelected: (val) {
                if (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedFilter = cat);
                }
              },
              selectedColor: const Color(0xFF546356),
              backgroundColor: Colors.white.withOpacity(0.85),
              labelStyle: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                color: isSel ? Colors.white : const Color(0xFF5E6059),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
                side: BorderSide(color: isSel ? const Color(0xFF546356) : const Color(0xFFE3E3DB)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_entries.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(36),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            const Icon(Icons.history_edu, size: 44, color: Color(0xFF546356)),
            const SizedBox(height: 14),
            Text(
              "Your Journey Begins Here",
              style: GoogleFonts.manrope(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF31332E)),
            ),
            const SizedBox(height: 6),
            Text(
              "No reflections written yet. Pause, contemplate, and capture your thoughts above.",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(color: const Color(0xFF5E6059), fontSize: 13, height: 1.4),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "PAST REFLECTIONS",
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: const Color(0xFF546356),
              ),
            ),
            Text(
              '${_entries.length} reflections',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5E6059),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _entries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final raw = _entries[index];
            final entry = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
            return _buildEntryCard(entry);
          },
        ),
      ],
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    final date = DateTime.tryParse(entry['date'] ?? '') ?? DateTime.now();
    final dateStr = DateFormat('EEEE, MMMM d').format(date);
    final content = entry['content']?.toString() ?? '';
    final prompt = entry['prompt']?.toString() ?? '';
    final snippet = content.length > 110 ? '${content.substring(0, 110)}...' : content;

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openEntrySheet(entry),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF546356).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        dateStr.toUpperCase(),
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: const Color(0xFF546356),
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 12, color: const Color(0xFF5E6059).withOpacity(0.4)),
                  ],
                ),
                if (prompt.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '"$prompt"',
                    style: GoogleFonts.newsreader(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF5E6059),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  snippet,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: const Color(0xFF31332E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class JournalEntrySheet extends StatefulWidget {
  final Map<String, dynamic>? entry;
  final String defaultPrompt;
  final VoidCallback onSaved;

  const JournalEntrySheet({
    super.key,
    this.entry,
    required this.defaultPrompt,
    required this.onSaved,
  });

  @override
  State<JournalEntrySheet> createState() => _JournalEntrySheetState();
}

class _JournalEntrySheetState extends State<JournalEntrySheet> {
  late TextEditingController _contentController;
  late String _prompt;
  bool _isSaving = false;
  bool _isDeleting = false;
  String _selectedMood = 'Peaceful';

  final List<Map<String, dynamic>> _moods = [
    {'name': 'Peaceful', 'icon': Icons.spa_outlined},
    {'name': 'Grateful', 'icon': Icons.favorite_border},
    {'name': 'Contemplative', 'icon': Icons.lightbulb_outline},
    {'name': 'Striving', 'icon': Icons.bolt},
  ];

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.entry?['content'] ?? '');
    _prompt = widget.entry?['prompt'] ?? widget.defaultPrompt;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_contentController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);
    final dateStr = widget.entry?['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final result = await ApiService.saveJournalEntry(
        content: _contentController.text.trim(),
        date: dateStr,
        prompt: _prompt,
      );

      if (mounted) {
        if (result['success']) {
          widget.onSaved();
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to save')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving reflection')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.entry == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete Reflection', style: GoogleFonts.manrope(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this reflection?', style: GoogleFonts.manrope(color: const Color(0xFF5E6059))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFA73B21), foregroundColor: Colors.white),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final result = await ApiService.deleteJournalEntry(widget.entry!['id']);
      if (mounted) {
        if (result['success']) {
          widget.onSaved();
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to delete')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error deleting entry')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = widget.entry != null 
        ? DateFormat('EEEE, MMMM d').format(DateTime.parse(widget.entry!['date']))
        : DateFormat('EEEE, MMMM d').format(DateTime.now());

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: const Color(0xFF546356),
                      ),
                    ),
                    Text(
                      'Reflective Entry',
                      style: GoogleFonts.manrope(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF31332E),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF5E6059)),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Prompt Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F4ED),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE3E3DB)),
              ),
              child: Text(
                _prompt,
                style: GoogleFonts.newsreader(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF31332E),
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Mood Chips
            Text(
              'HEART STATE',
              style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: const Color(0xFF5E6059)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _moods.map((m) {
                final isSel = _selectedMood == m['name'];
                return ChoiceChip(
                  avatar: Icon(m['icon'] as IconData, size: 14, color: isSel ? Colors.white : const Color(0xFF546356)),
                  label: Text(m['name'] as String),
                  selected: isSel,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedMood = m['name'] as String);
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

            // Content input
            Text(
              'REFLECTION',
              style: GoogleFonts.manrope(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: const Color(0xFF5E6059)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contentController,
              maxLines: 6,
              autofocus: widget.entry == null,
              style: GoogleFonts.manrope(fontSize: 15, height: 1.5, color: const Color(0xFF31332E)),
              decoration: InputDecoration(
                hintText: 'Pour your heart out in gratitude, contemplation, and sincere du\'a...',
                hintStyle: GoogleFonts.manrope(color: const Color(0xFFB2B2AB), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF5F4ED),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              children: [
                if (widget.entry != null) ...[
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        onPressed: _isDeleting ? null : _delete,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFA73B21),
                          side: const BorderSide(color: Color(0xFFA73B21)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        ),
                        child: _isDeleting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA73B21)))
                            : Text('DELETE', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF546356),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('SAVE REFLECTION', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
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
