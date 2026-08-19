import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'notification_service.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  Map<String, dynamic>? _user;
  List<dynamic> _prayerMethods = [];
  bool _isLoading = true;

  bool _notifyPrayer = true;
  bool _notifyTask = true;
  bool _notifyJournal = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifyPrayer = prefs.getBool(NotificationService.prefPrayerNotifications) ?? true;
      _notifyTask = prefs.getBool(NotificationService.prefTaskReminders) ?? true;
      _notifyJournal = prefs.getBool(NotificationService.prefJournalReminder) ?? true;
    });
  }

  Future<void> _toggleNotificationPref(String key, bool val) async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, val);
    await _loadNotificationPreferences();

    if (key == NotificationService.prefJournalReminder) {
      await NotificationService().scheduleDailyJournalReminder();
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchUserData(),
      _fetchPrayerMethods(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchUserData() async {
    try {
      final result = await ApiService.getUser();
      if (result['success']) {
        setState(() {
          _user = result['data'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  Future<void> _fetchPrayerMethods() async {
    try {
      final result = await ApiService.getPrayerMethods();
      if (result['success']) {
        setState(() {
          _prayerMethods = result['data']['data'] as List;
        });
      }
    } catch (e) {
      debugPrint('Error fetching prayer methods: $e');
    }
  }

  String _getPrayerMethodName(int id) {
    if (_prayerMethods.isEmpty) return 'MWL (Standard)';
    for (var m in _prayerMethods) {
      if (m is Map && m['id'] == id) {
        return m['name'] ?? 'Muslim World League';
      }
    }
    return 'Muslim World League';
  }

  Future<void> _editName() async {
    final nameController = TextEditingController(text: _user?['name'] ?? 'Muslim');
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFBF9F4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Edit Name', style: GoogleFonts.manrope(fontWeight: FontWeight.bold, color: const Color(0xFF31332E))),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: GoogleFonts.manrope(fontWeight: FontWeight.w600, color: const Color(0xFF31332E)),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            filled: true,
            fillColor: const Color(0xFFF5F4ED),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CANCEL', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, color: const Color(0xFF5E6059))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF546356),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            ),
            child: Text('SAVE', style: GoogleFonts.manrope(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      await ApiService.updateSettings(name: newName);
      _fetchUserData();
    }
  }

  Future<void> _updateCity() async {
    final selectedCity = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _CitySearchSheet(initialCity: _user?['city']),
    );

    if (selectedCity != null && selectedCity.isNotEmpty && selectedCity != _user?['city']) {
      final result = await ApiService.updateSettings(city: selectedCity);
      if (result['success']) {
        _fetchUserData();
      }
    }
  }

  Future<void> _updatePrayerMethod() async {
    final selectedMethodId = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE3E3DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  const Icon(Icons.schedule_outlined, color: Color(0xFF546356), size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'CALCULATION METHOD',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      color: const Color(0xFF31332E),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _prayerMethods.length,
                itemBuilder: (context, index) {
                  final method = _prayerMethods[index];
                  final isSelected = method['id'] == _user?['prayer_method'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF546356).withOpacity(0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF546356).withOpacity(0.3) : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                      title: Text(
                        method['name'] ?? 'Unknown Method',
                        style: GoogleFonts.manrope(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF546356) : const Color(0xFF31332E),
                        ),
                      ),
                      trailing: isSelected 
                          ? const Icon(Icons.check_circle, color: Color(0xFF546356), size: 20)
                          : null,
                      onTap: () => Navigator.pop(context, method['id']),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedMethodId != null && selectedMethodId != _user?['prayer_method']) {
      final result = await ApiService.updateSettings(prayerMethod: selectedMethodId);
      if (result['success']) {
        _fetchUserData();
      }
    }
  }

  Future<void> _toggleHanafi() async {
    HapticFeedback.selectionClick();
    final currentHanafi = _user?['is_hanafi'] ?? false;
    await ApiService.updateSettings(isHanafi: !currentHanafi);
    _fetchUserData();
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
            child: Column(
              children: [
                _buildTopAppBar(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF546356)))
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Hero Profile Card
                              _buildProfileHeroCard(),
                              const SizedBox(height: 24),

                              // 2. Statistics Grid
                              _buildSectionTitle('SPIRITUAL CONSISTENCY'),
                              const SizedBox(height: 12),
                              _buildStatsGrid(),
                              const SizedBox(height: 28),

                              // 3. Settings & Jurisprudence
                              _buildSectionTitle('PRAYER & JURISPRUDENCE'),
                              const SizedBox(height: 12),
                              _buildSettingsCard(),
                              const SizedBox(height: 28),

                              // 4. Notifications & Reminders
                              _buildSectionTitle('NOTIFICATIONS & SACRED PAUSES'),
                              const SizedBox(height: 12),
                              _buildNotificationSettingsCard(),
                              const SizedBox(height: 28),

                              // 5. Offline Status Badge
                              _buildOfflinePrivacyBanner(),
                              const SizedBox(height: 120),
                            ],
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
          top: -80,
          right: -60,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                color: const Color(0xFFD7E7D6).withOpacity(0.35),
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
                    'SANCTUARY',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: const Color(0xFF546356),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Me & Settings',
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
                  color: const Color(0xFFD7E7D6),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: Color(0xFF546356)),
                    const SizedBox(width: 4),
                    Text(
                      'Encrypted',
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

  Widget _buildProfileHeroCard() {
    final userName = _user?['name'] ?? 'Muslim';
    final userCity = _user?['city'] ?? 'Addis Ababa, Ethiopia';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF546356), Color(0xFF3B4A3C)],
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
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            userName,
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _editName,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFFD7E7D6)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            userCity,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              color: const Color(0xFFD7E7D6),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Offline On-Device Sanctuary',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFD7E7D6),
                  ),
                ),
                Text(
                  '100% Private',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: const Color(0xFF546356),
      ),
    );
  }

  Widget _buildStatsGrid() {
    final journalCount = _user?['journal_entries_count'] ?? 0;
    final tasksCount = _user?['tasks_count'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatItem('REFLECTIONS', journalCount.toString(), Icons.menu_book_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem('ROUTINE TASKS', tasksCount.toString(), Icons.task_alt_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem('STORAGE', 'On-Device', Icons.save_outlined),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF31332E).withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF546356), size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF31332E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: const Color(0xFF5E6059),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    final isHanafi = _user?['is_hanafi'] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF31332E).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.location_on_outlined,
            title: 'Location & Coordinates',
            subtitle: _user?['city'] ?? 'Addis Ababa, Ethiopia',
            onTap: _updateCity,
          ),
          _buildCardDivider(),
          _buildSettingsTile(
            icon: Icons.schedule_outlined,
            title: 'Prayer Calculation Method',
            subtitle: _getPrayerMethodName(_user?['prayer_method'] ?? 3),
            onTap: _updatePrayerMethod,
          ),
          _buildCardDivider(),
          _buildSettingsTile(
            icon: Icons.balance_outlined,
            title: 'Asr Juristic Method (Madhab)',
            subtitle: isHanafi ? 'Hanafi (Later Asr)' : 'Shafi / Standard (Earlier Asr)',
            onTap: _toggleHanafi,
            trailingWidget: Switch(
              value: isHanafi,
              activeColor: const Color(0xFF546356),
              onChanged: (val) => _toggleHanafi(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF31332E).withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSwitchTile(
            icon: Icons.notifications_active_outlined,
            title: 'Prayer Adhan Reminders',
            subtitle: 'Notify at Fajr, Dhuhr, Asr, Maghrib & Isha',
            value: _notifyPrayer,
            onChanged: (val) => _toggleNotificationPref(NotificationService.prefPrayerNotifications, val),
          ),
          _buildCardDivider(),
          _buildSwitchTile(
            icon: Icons.task_alt_outlined,
            title: 'Daily Routine Task Reminders',
            subtitle: 'Notify at scheduled task times outside prayer buffers',
            value: _notifyTask,
            onChanged: (val) => _toggleNotificationPref(NotificationService.prefTaskReminders, val),
          ),
          _buildCardDivider(),
          _buildSwitchTile(
            icon: Icons.auto_stories_outlined,
            title: 'Evening Journal Reflection',
            subtitle: 'Daily gentle reminder at 9:00 PM',
            value: _notifyJournal,
            onChanged: (val) => _toggleNotificationPref(NotificationService.prefJournalReminder, val),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailingWidget,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF546356).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF546356), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF31332E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: const Color(0xFF5E6059),
                    ),
                  ),
                ],
              ),
            ),
            if (trailingWidget != null)
              trailingWidget
            else
              const Icon(Icons.chevron_right, color: Color(0xFFB2B2AB), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF546356).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF546356), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF31332E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: const Color(0xFF5E6059),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: const Color(0xFF546356),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildCardDivider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: const Color(0xFFE3E3DB),
    );
  }

  Widget _buildOfflinePrivacyBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFD7E7D6).withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF546356).withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user_outlined, color: Color(0xFF546356), size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '100% PRIVATE & OFFLINE SANCTUARY',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: const Color(0xFF546356),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CitySearchSheet extends StatefulWidget {
  final String? initialCity;
  const _CitySearchSheet({this.initialCity});

  @override
  State<_CitySearchSheet> createState() => _CitySearchSheetState();
}

class _CitySearchSheetState extends State<_CitySearchSheet> {
  final _controller = TextEditingController();
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialCity ?? '';
    _onSearchChanged(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    final results = await ApiService.searchCities(query);
    if (mounted) {
      setState(() {
        _suggestions = results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 14),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE3E3DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(Icons.location_city_outlined, color: Color(0xFF546356), size: 22),
              const SizedBox(width: 10),
              Text(
                'SELECT CITY (OFFLINE)',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: const Color(0xFF31332E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            onChanged: _onSearchChanged,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search city name...',
              hintStyle: GoogleFonts.manrope(color: const Color(0xFFB2B2AB)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF546356)),
              filled: true,
              fillColor: const Color(0xFFF5F4ED),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
            style: GoogleFonts.manrope(color: const Color(0xFF31332E), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final city = _suggestions[index];
                return ListTile(
                  title: Text(
                    city,
                    style: GoogleFonts.manrope(
                      color: const Color(0xFF31332E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, city),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFB2B2AB), size: 20),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
