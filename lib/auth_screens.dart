import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'screens/dashboard_screens.dart';

class AnimatedBackground extends StatelessWidget {
  final Widget child;
  const AnimatedBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF06091B),
              const Color(0xFF000000),
            ],
          ),
        ),
        child: child,
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String _errorMessage = '';

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'All fields required');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse("https://abes.platform.simplifii.com/api/v1/admin/authenticate"),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Origin': 'https://abes.web.simplifii.com',
          'Referer': 'https://abes.web.simplifii.com/',
        },
        body: 'username=$username&password=$password',
      );

      debugPrint('Login API status: ${response.statusCode}');
      debugPrint('Login API response: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final token = json['token'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          await prefs.setString('name', json['response']?['name'] ?? username);
          final studentId = json['response']?['unique_code']?.toString() ?? username;
          final studentNumber = json['response']?['id']?.toString() ?? studentId;
          await prefs.setString('student_id', studentId);
          await prefs.setString('student_number', studentNumber);
          // Save string10 as user_pin
          final userPin = json['response']?['string10']?.toString() ?? '0000';
          await prefs.setString('user_pin', userPin);
          debugPrint('Stored student_id: $studentId, student_number: $studentNumber, user_pin: $userPin');
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Dashboard()));
        } else {
          setState(() => _errorMessage = 'Invalid credentials');
        }
      } else {
        setState(() => _errorMessage = 'Login failed');
      }
    } catch (e) {
      debugPrint('Login error: $e');
      setState(() => _errorMessage = 'Connection error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final usernameController = TextEditingController();
    String errorMessage = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2139).withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        contentPadding: const EdgeInsets.all(20),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reset Password',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2D47),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: usernameController,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Enter Username',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ),
                if (errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage,
                    style: TextStyle(color: Colors.red.shade300, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final username = usernameController.text.trim();
                        if (username.isEmpty) {
                          setDialogState(() => errorMessage = 'Username required');
                          return;
                        }
                        setDialogState(() => errorMessage = '');
                        try {
                          final response = await http.patch(
                            Uri.parse('https://abes.platform.simplifii.com/api/v1/forgotpassword'),
                            headers: {
                              'Content-Type': 'application/x-www-form-urlencoded',
                              'Origin': 'https://abes.web.simplifii.com',
                              'Referer': 'https://abes.web.simplifii.com/',
                            },
                            body:
                            'username=$username&reset_password_base_url=https://abes.web.simplifii.com/reset_password.php',
                          );
                          debugPrint('Forgot Password API status: ${response.statusCode}');
                          debugPrint('Forgot Password API response: ${response.body}');
                          if (response.statusCode == 200) {
                            final json = jsonDecode(response.body);
                            final message = json['msg'] ?? 'Password reset link sent';
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF2A2D47),
                                content: Text(
                                  message,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                duration: const Duration(seconds: 4),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                margin: const EdgeInsets.all(16),
                              ),
                            );
                          } else {
                            setDialogState(() => errorMessage = 'Failed: ${response.statusCode}');
                          }
                        } catch (e) {
                          debugPrint('Forgot Password error: $e');
                          setDialogState(() => errorMessage = 'Error: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text('Submit'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: SafeArea(
        child: Stack(
          children: [
            // Main content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Login form
                    _buildLoginForm(),
                  ],
                ),
              ),
            ),

            // Developer credit at bottom
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'developed by Arihant Singh',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.4),
                    fontWeight: FontWeight.w300,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 350),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2139).withOpacity(0.4),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          const Text(
            'LOGIN TO\nYOUR ACCOUNT',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Enter your login information',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 32),

          // Username field
          _buildInputField(
            controller: _usernameController,
            hint: 'Username',
            icon: Icons.person_outline,
          ),

          const SizedBox(height: 16),

          // Password field
          _buildInputField(
            controller: _passwordController,
            hint: 'Password',
            icon: Icons.lock_outline,
            isPassword: true,
          ),

          const SizedBox(height: 24),

          // Error message
          if (_errorMessage.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                _errorMessage,
                style: TextStyle(
                  color: Colors.red.shade300,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Login button
          _buildLoginButton(),

          const SizedBox(height: 8),

          // Forgot Password link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D47),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: Colors.white.withOpacity(0.5),
            size: 20,
          ),
          suffixIcon: isPassword
              ? IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white.withOpacity(0.5),
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          )
              : null,
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: _isLoading
            ? LinearGradient(
          colors: [
            Colors.grey.withOpacity(0.4),
            Colors.grey.withOpacity(0.6),
          ],
        )
            : const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF4A90E2),
            Color(0xFF187AD6),
          ],
        ),
        boxShadow: [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _login,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.center,
            child: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Text(
              'LOGIN',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}