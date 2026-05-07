import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_service.dart';
import 'login_screen.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  Map<String, dynamic>? _user;
  List<dynamic> _prayerMethods = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
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
          _prayerMethods = (result['data']['data'] as Map).values.toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching prayer methods: $e');
    }
  }

  String _getPrayerMethodName(int id) {
    if (_prayerMethods.isEmpty) return 'Loading...';
    final method = _prayerMethods.firstWhere(
      (m) => m['id'] == id,
      orElse: () => null,
    );
    return method?['name'] ?? 'Custom';
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

  Future<void> _handleLogout() async {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.white.withOpacity(0.9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'LOGOUT',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              color: const Color(0xFF31332E),
            ),
          ),
          content: Text(
            'Are you sure you want to leave the sanctuary?',
            style: GoogleFonts.manrope(
              fontSize: 16,
              color: const Color(0xFF5E6059),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CANCEL',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5E6059),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await ApiService.logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: Text(
                'LOGOUT',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFA73B21),
                ),
              ),
            ),
          ],
        ),
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
                        const SizedBox(height: 48),
                        _buildLogoutButton(),
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
                    Text(
                      _user?['name'] ?? 'Guest User',
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF31332E),
                      ),
                    ),
                    Text(
                      _user?['email'] ?? 'guest@example.com',
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
          child: _buildStatCard('STREAK', '0', Icons.local_fire_department),
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
              fontSize: 24,
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
            _user?['city'] ?? 'Addis Ababa',
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
          _buildSettingsItem(Icons.notifications_none_outlined, 'Notifications', 'Enabled'),
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

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _handleLogout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFA73B21).withOpacity(0.2)),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Center(
          child: Text(
            'LOGOUT',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              color: const Color(0xFFA73B21),
            ),
          ),
        ),
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
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialCity ?? '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length < 3) {
        setState(() {
          _suggestions = [];
          _isSearching = false;
        });
        return;
      }

      setState(() => _isSearching = true);
      final results = await ApiService.searchCities(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = false;
        });
      }
    });
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
            'SEARCH CITY',
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
              hintText: 'Start typing city name...',
              hintStyle: GoogleFonts.manrope(color: const Color(0xFFB2B2AB)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF546356)),
              suffixIcon: _isSearching 
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF546356)),
                      ),
                    )
                  : null,
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
            child: _suggestions.isEmpty && _controller.text.length >= 3 && !_isSearching
                ? Center(
                    child: Text(
                      'No cities found',
                      style: GoogleFonts.manrope(color: const Color(0xFF5E6059)),
                    ),
                  )
                : ListView.builder(
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
