import 'dart:ui';
import 'package:flutter/material.dart';
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
  String _currentPrompt = "What are you grateful for in this quiet moment?";
  bool _isLoading = true;
  final DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final promptResult = await ApiService.getJournalPrompt();
      if (promptResult['success']) {
        setState(() {
          _currentPrompt = promptResult['data']['data']['prompt'];
        });
      }

      final entriesResult = await ApiService.getJournalEntries();
      if (entriesResult['success']) {
        setState(() {
          _entries = entriesResult['data']['data'];
        });
      }
    } catch (e) {
      print('Error loading journal data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openEntrySheet([Map<String, dynamic>? entry]) {
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
    return Scaffold(
      backgroundColor: const Color(0xFFFBF9F4),
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
                          onRefresh: _loadData,
                          color: const Color(0xFF546356),
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(),
                                const SizedBox(height: 32),
                                _buildPromptCard(),
                                const SizedBox(height: 48),
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
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "MY REFLECTIONS",
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            color: const Color(0xFF5E6059),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Your Sacred Journey",
          style: GoogleFonts.manrope(
            fontSize: 32,
            fontWeight: FontWeight.w200,
            color: const Color(0xFF31332E),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptCard() {
    // Check if there's already an entry for today
    final todayStr = DateFormat('yyyy-MM-dd').format(_today);
    final todayEntry = _entries.firstWhere(
      (e) => e['date'] == todayStr,
      orElse: () => null,
    );

    return GestureDetector(
      onTap: () => _openEntrySheet(todayEntry),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F4ED),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFF546356).withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF546356), size: 16),
                const SizedBox(width: 8),
                Text(
                  'PROMPT OF THE DAY',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: const Color(0xFF546356),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              todayEntry != null ? "Continue your reflection..." : _currentPrompt,
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w300,
                height: 1.3,
                color: const Color(0xFF31332E),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF546356),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    todayEntry != null ? 'VIEW' : 'WRITE',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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

  Widget _buildHistorySection() {
    if (_entries.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.history_edu, size: 48, color: const Color(0xFFB2B2AB).withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              "No reflections yet.\nStart your journey today.",
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: const Color(0xFFB2B2AB),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "HISTORY",
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            color: const Color(0xFF5E6059),
          ),
        ),
        const SizedBox(height: 24),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _entries.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final entry = _entries[index];
            return _buildEntryCard(entry);
          },
        ),
      ],
    );
  }

  Widget _buildEntryCard(Map<String, dynamic> entry) {
    final date = DateTime.parse(entry['date']);
    final dateStr = DateFormat('EEEE, MMMM d').format(date);
    final content = entry['content'] as String;
    final snippet = content.length > 80 ? '${content.substring(0, 80)}...' : content;

    return GestureDetector(
      onTap: () => _openEntrySheet(entry),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.5)),
        ),
        child: Column(
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
            const SizedBox(height: 8),
            Text(
              snippet,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: const Color(0xFF31332E),
              ),
            ),
          ],
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
            imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                color: const Color(0xFFD7E7D6).withOpacity(0.2),
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
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE3E3DB),
                ),
                child: const Icon(Icons.person_outline, color: Color(0xFF546356), size: 20),
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
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.entry?['content'] ?? '');
    _prompt = widget.entry?['prompt'] ?? widget.defaultPrompt;
    _isEditing = widget.entry == null;
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
          const SnackBar(content: Text('Network error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.entry == null) return;
    
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
          const SnackBar(content: Text('Network error')),
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
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                          color: const Color(0xFF5E6059),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.entry == null ? 'New Reflection' : 'View Reflection',
                        style: GoogleFonts.manrope(
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          color: const Color(0xFF31332E),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFFB2B2AB)),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F4ED),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PROMPT',
                      style: GoogleFonts.manrope(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: const Color(0xFF5E6059),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _prompt,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF31332E),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (_isEditing)
                TextField(
                  controller: _contentController,
                  maxLines: 8,
                  autofocus: true,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    height: 1.6,
                    color: const Color(0xFF31332E),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Begin your reflection here...',
                    hintStyle: GoogleFonts.manrope(color: const Color(0xFFE3E3DB)),
                    border: InputBorder.none,
                  ),
                )
              else
                Text(
                  _contentController.text,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    height: 1.6,
                    color: const Color(0xFF31332E),
                  ),
                ),
              const SizedBox(height: 40),
              Row(
                children: [
                  if (widget.entry != null) ...[
                    IconButton(
                      onPressed: _isDeleting ? null : _delete,
                      icon: _isDeleting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.delete_outline, color: Color(0xFFA73B21)),
                    ),
                    const Spacer(),
                  ],
                  if (!_isEditing)
                    ElevatedButton(
                      onPressed: () => setState(() => _isEditing = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F4ED),
                        foregroundColor: const Color(0xFF546356),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'EDIT',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                      ),
                    ),
                  if (_isEditing) ...[
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF546356),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      ),
                      child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(
                            'SAVE',
                            style: GoogleFonts.manrope(fontWeight: FontWeight.w800, letterSpacing: 1.0),
                          ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
