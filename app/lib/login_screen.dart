import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isSignIn = true;
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Please fill in all fields');
      return;
    }

    if (!_isSignIn && _nameController.text.isEmpty) {
      _showError('Please enter your name');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = _isSignIn
          ? await ApiService.login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            )
          : await ApiService.register(
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );

      if (result['success']) {
        _showSuccess(_isSignIn ? 'Welcome back!' : 'Account created!');
        // Handle navigation to home screen here
      } else {
        _showError(result['message']);
      }
    } catch (e) {
      _showError('Connection failed. Is the server running?');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF546356),
        behavior: SnackBarBehavior.floating,
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 48),
                  _buildAuthCard(),
                  const SizedBox(height: 48),
                  _buildFooter(),
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
          right: -100,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                color: const Color(0xFFD7E7D6).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          left: -100,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                color: const Color(0xFFDCE5D7).withOpacity(0.3),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFE3E3DB),
            borderRadius: BorderRadius.circular(24),
          ),
          transform: Matrix4.rotationZ(0.05),
          child: const Center(
            child: Icon(
              Icons.spa,
              color: Color(0xFF546356),
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'THE SACRED PAUSE',
          style: GoogleFonts.manrope(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: const Color(0xFF31332E),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'A sanctuary for your intentional day.',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w300,
            color: const Color(0xFF5E6059),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard() {
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
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF31332E).withOpacity(0.06),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAuthToggle(),
              const SizedBox(height: 32),
              if (!_isSignIn) ...[
                _buildLabel('Full Name'),
                _buildTextField(
                  controller: _nameController,
                  hint: 'John Doe',
                ),
                const SizedBox(height: 20),
              ],
              _buildLabel('Email Address'),
              _buildTextField(
                controller: _emailController,
                hint: 'name@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLabel('Password'),
                  if (_isSignIn)
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'FORGOT?',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: const Color(0xFF546356),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _passwordController,
                hint: '••••••••',
                obscureText: true,
              ),
              const SizedBox(height: 32),
              _buildMainButton(),
              const SizedBox(height: 24),
              _buildDivider(),
              const SizedBox(height: 24),
              _buildGoogleButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4ED),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isSignIn = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isSignIn ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: _isSignIn
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: _isSignIn ? FontWeight.w600 : FontWeight.w500,
                      color: _isSignIn
                          ? const Color(0xFF31332E)
                          : const Color(0xFF5E6059),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isSignIn = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isSignIn ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: !_isSignIn
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    'Register',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: !_isSignIn ? FontWeight.w600 : FontWeight.w500,
                      color: !_isSignIn
                          ? const Color(0xFF31332E)
                          : const Color(0xFF5E6059),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: const Color(0xFF5E6059),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: GoogleFonts.manrope(
        color: const Color(0xFF31332E),
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(
          color: const Color(0xFF7A7B75).withOpacity(0.5),
        ),
        filled: true,
        fillColor: const Color(0xFFE3E3DB).withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(18),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFD7E7D6), width: 2),
        ),
      ),
    );
  }

  Widget _buildMainButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(100),
        gradient: LinearGradient(
          colors: _isLoading 
            ? [const Color(0xFF7A7B75), const Color(0xFF5E6059)]
            : [const Color(0xFF546356), const Color(0xFF48574A)],
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
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                _isSignIn ? 'Sign In' : 'Register',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE3E3DB))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR CONTINUE WITH',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              color: const Color(0xFFB2B2AB),
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE3E3DB))),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          side: BorderSide(
            color: const Color(0xFFB2B2AB).withOpacity(0.2),
          ),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.string(
              '''<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/><path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/><path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05"/><path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/></svg>''',
              height: 20,
              width: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Google',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF31332E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
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
                    height: 150,
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
                      stops: [0.0, 0.5],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildFooterLink('Privacy'),
            const SizedBox(width: 32),
            _buildFooterLink('Terms'),
            const SizedBox(width: 32),
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
        fontWeight: FontWeight.bold,
        letterSpacing: 2.0,
        color: const Color(0xFF5E6059),
      ),
    );
  }
}
