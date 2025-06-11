import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'screens/dashboard_screens.dart';
import 'widgets/glass_card.dart';

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
              const Color(0xFF0D1123),
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

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  late final AnimationController _errorController = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );
  late final Animation<Offset> _errorSlideAnimation = Tween<Offset>(begin: const Offset(3.0, 0.5), end: Offset.zero)
      .animate(CurvedAnimation(parent: _errorController, curve: Curves.easeOut));

  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_errorMessage.isNotEmpty) {
      _errorController.forward();
    } else {
      _errorController.reverse();
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _errorController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Enter both fields');
      return;
    }
    setState(() => _isLoading = true);
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
          await prefs.setString('name', json['response']?["name"] ?? username);
          final studentId = json['sub']?.toString() ?? username;
          final studentNumber = json['response']?['id']?.toString() ?? studentId;
          await prefs.setString('student_id', studentId);
          await prefs.setString('student_number', studentNumber);
          debugPrint('Stored student_id: $studentId, student_number: $studentNumber');
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Dashboard()));
        } else {
          setState(() => _errorMessage = 'Invalid credentials or token missing');
        }
      } else {
        setState(() => _errorMessage = 'Login failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Login error: $e');
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF06B6D4)]),
                    ),
                    child: const Icon(Icons.lock_outline, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 30),
                  const Text('Hey There!', style: TextStyle(fontFamily: "Poppins-Bold", fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Sign in to continue', style: TextStyle(fontSize: 16, fontFamily: "Poppins-SemiBold", color: Colors.white.withOpacity(0.7))),
                  const SizedBox(height: 40),
                  _buildTextField(controller: _usernameController, label: 'Username', icon: Icons.person_outline),
                  const SizedBox(height: 20),
                  _buildTextField(controller: _passwordController, label: 'Password', icon: Icons.lock_outline, isPassword: true),
                  const SizedBox(height: 30),
                  if (_errorMessage.isNotEmpty)
                    SlideTransition(
                      position: _errorSlideAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(_errorMessage, style: const TextStyle(color: Colors.red))),
                            GestureDetector(
                              onTap: () => setState(() => _errorMessage = ''),
                              child: Icon(Icons.close, color: Colors.red.withOpacity(0.7), size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_errorMessage.isNotEmpty) const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        padding: EdgeInsets.zero,
                        elevation: 3,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF06B6D4)]),
                          borderRadius: BorderRadius.circular(55),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7), fontFamily: 'Poppins-Regular'),
          prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.7)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          floatingLabelBehavior: FloatingLabelBehavior.auto,
        ),
      ),
    );
  }
}