import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
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
            const SizedBox(height: 12),
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
              child: Text(
                'PRAYER CALCULATION METHOD',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: const Color(0xFF31332E),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _prayerMethods.length,
                itemBuilder: (context, index) {
                  final method = _prayerMethods[index];
                  final isSelected = method['id'] == _user?['prayer_method'];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    title: Text(
                      method['name'] ?? 'Unknown Method',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF546356) : const Color(0xFF31332E),
                      ),
                    ),
                    trailing: isSelected 
                        ? const Icon(Icons.check, color: Color(0xFF546356))
                        : null,
                    onTap: () => Navigator.pop(context, method['id']),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF546356)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopHeader(),
                        const SizedBox(height: 48),
                        _buildProfileCard(),
                        const SizedBox(height: 32),
                        _buildSectionHeader('STATISTICS'),
                        const SizedBox(height: 16),
                        _buildStatsGrid(),
                        const SizedBox(height: 32),
                        _buildSectionHeader('SETTINGS'),
                        const SizedBox(height: 16),
                        _buildSettingsList(),
                        const SizedBox(height: 32),
                        _buildSectionHeader('NOTIFICATIONS & REMINDERS'),
                        const SizedBox(height: 16),
                        _buildNotificationSettingsList(),
                        const SizedBox(height: 48),
                        _buildOfflineStatusBanner(),
                        const SizedBox(height: 120),
                      ],
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
          left: -50,
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
      ],
    );
  }

  Widget _buildTopHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR SANCTUARY',
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: const Color(0xFF5E6059),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Me',
          style: GoogleFonts.manrope(
            fontSize: 36,
            fontWeight: FontWeight.w200,
            color: const Color(0xFF31332E),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    return InkWell(
      onTap: _editName,
      borderRadius: BorderRadius.circular(32),
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
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE3E3DB),
                  ),
                  child: const Icon(Icons.person_outline, color: Color(0xFF546356), size: 40),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _user?['name'] ?? 'Muslim',
                              style: GoogleFonts.manrope(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF31332E),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF546356)),
                        ],
                      ),
                      Text(
                        '100% Offline Sanctuary',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          color: const Color(0xFF5E6059),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: const Color(0xFF31332E),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard('JOURNAL', (_user?['journal_entries_count'] ?? 0).toString(), Icons.auto_stories),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard('TASKS', (_user?['tasks_count'] ?? 0).toString(), Icons.check_circle_outline),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard('MODE', 'Offline', Icons.wifi_off),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4ED),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF546356), size: 20),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF31332E),
            ),
          ),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: const Color(0xFF5E6059),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList() {
    final isHanafi = _user?['is_hanafi'] ?? false;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4ED),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildSettingsItem(
            Icons.location_on_outlined, 
            'Location', 
            _user?['city'] ?? 'Addis Ababa, Ethiopia',
            onTap: _updateCity,
          ),
          _buildDivider(),
          _buildSettingsItem(
            Icons.schedule_outlined, 
            'Prayer Method', 
            _getPrayerMethodName(_user?['prayer_method'] ?? 3),
            onTap: _updatePrayerMethod,
          ),
          _buildDivider(),
          _buildSettingsItem(
            Icons.balance_outlined, 
            'Asr Calculation (Madhab)', 
            isHanafi ? 'Hanafi' : 'Shafi / Standard',
            onTap: _toggleHanafi,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettingsList() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4ED),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildSwitchItem(
            Icons.notifications_active_outlined,
            'Prayer Times (Adhan)',
            'Notify at Fajr, Dhuhr, Asr, Maghrib & Isha',
            _notifyPrayer,
            (val) => _toggleNotificationPref(NotificationService.prefPrayerNotifications, val),
          ),
          _buildDivider(),
          _buildSwitchItem(
            Icons.task_alt_outlined,
            'Task Reminders',
            'Notify at scheduled task times',
            _notifyTask,
            (val) => _toggleNotificationPref(NotificationService.prefTaskReminders, val),
          ),
          _buildDivider(),
          _buildSwitchItem(
            Icons.book_outlined,
            'Daily Journal Reflection',
            'Evening reflection reminder (9:00 PM)',
            _notifyJournal,
            (val) => _toggleNotificationPref(NotificationService.prefJournalReminder, val),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchItem(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF546356), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
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
          Switch(
            value: value,
            activeColor: const Color(0xFF546356),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF546356), size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF31332E),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: const Color(0xFF5E6059),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFFB2B2AB), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: const Color(0xFF31332E).withOpacity(0.05),
    );
  }

  Widget _buildOfflineStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFD7E7D6).withOpacity(0.4),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFF546356).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, color: Color(0xFF546356), size: 20),
          const SizedBox(width: 12),
          Text(
            '100% OFFLINE MODE ACTIVE',
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: const Color(0xFF546356),
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
          const SizedBox(height: 12),
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
            'SELECT CITY (OFFLINE)',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              color: const Color(0xFF31332E),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            onChanged: _onSearchChanged,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Type city name...',
              hintStyle: GoogleFonts.manrope(color: const Color(0xFFB2B2AB)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF546356)),
              filled: true,
              fillColor: const Color(0xFFF5F4ED),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
            style: GoogleFonts.manrope(color: const Color(0xFF31332E)),
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
