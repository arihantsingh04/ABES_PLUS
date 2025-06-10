import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '/auth_screens.dart';
import '/models/student.dart';
import '/widgets/student_info_card.dart';
import '/widgets/attendance_screen.dart';
import '/utils/helpers.dart';
import '/services/api_service.dart';
import '/widgets/glass_card.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  Student? student;
  String section = 'Unknown';
  String semester = '';
  String batch = 'Unknown';
  bool isWifiOn = false;
  late AnimationController _wifiController;
  late Animation<double> _wifiAnimation;
  late AnimationController _avatarController;
  late Animation<double> _avatarScale;
  bool _isRefreshing = false; // Track refresh state

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _wifiController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _wifiAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _wifiController, curve: Curves.easeInOut));
    _avatarController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _avatarScale = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _avatarController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _wifiController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final name = prefs.getString('name') ?? 'Student';
    final studentId = prefs.getString('student_id') ?? '';
    final dept = prefs.getString('dept') ?? 'Unknown';
    final section = prefs.getString('section') ?? 'Unknown';
    final semester = prefs.getString('semester') ?? '';
    final batch = prefs.getString('batch') ?? 'Unknown';

    setState(() {
      student = Student(
        name: name,
        email: 'N/A',
        rollNumber: studentId,
        branch: dept,
      );
      this.section = section;
      this.semester = semester;
      this.batch = batch;
    });

    if (token.isEmpty || studentId.isEmpty) {
      debugPrint('No token or student_id found for fetching user info');
      return;
    }

    try {
      final userInfo = await ApiService.fetchUserInfo(token, studentId);
      if (userInfo != null) {
        setState(() {
          student = Student(
            name: name,
            email: 'N/A',
            rollNumber: studentId,
            branch: userInfo['dept'],
          );
          this.section = userInfo['section'];
          this.semester = userInfo['semester'];
          this.batch = userInfo['batch'];
        });

        await prefs.setString('dept', userInfo['dept']);
        await prefs.setString('section', userInfo['section']);
        await prefs.setString('semester', userInfo['semester']);
        await prefs.setString('batch', userInfo['batch']);

        debugPrint('Stored user info - dept: ${userInfo['dept']}, section: ${userInfo['section']}, semester: ${userInfo['semester']}, batch: ${userInfo['batch']}');
      } else {
        debugPrint('No data found in API response');
      }
    } catch (e) {
      debugPrint('User info fetch error: $e');
    }
  }

  Future<void> _logout() async {
    await (await SharedPreferences.getInstance()).clear();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _toggleWifi() {
    setState(() {
      isWifiOn = !isWifiOn;
      isWifiOn ? _wifiController.forward() : _wifiController.reverse();
    });
  }

  Future<void> _refreshDashboard() async {
    setState(() => _isRefreshing = true);
    await _loadUserInfo();
    // AttendanceScreen's refreshCallback will reset _isRefreshing
  }

  @override
  Widget build(BuildContext context) {
    final firstName = student?.name.split(" ").first ?? 'Student';
    return AnimatedBackground(
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshDashboard,
          color: const Color(0xFF6366F1),
          backgroundColor: Colors.white.withOpacity(0.1),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          ScaleTransition(
                            scale: _avatarScale,
                            child: CircleAvatar(
                              radius: 24,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: Text(
                                firstName.isNotEmpty ? firstName[0].toUpperCase() : 'S',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                getGreeting(),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.7),
                                  fontFamily: 'Poppins-Regular',
                                ),
                              ),
                              Text(
                                firstName,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Poppins-Bold'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _toggleWifi,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                              ),
                              border: Border.all(color: Colors.white.withOpacity(isWifiOn ? 0.4 : 0.2)),
                              boxShadow: [
                                BoxShadow(
                                  color: isWifiOn
                                      ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                                      : Colors.transparent,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: AnimatedBuilder(
                              animation: _wifiAnimation,
                              builder: (context, _) => Icon(
                                isWifiOn ? Icons.wifi : Icons.wifi_off,
                                color: Colors.white.withOpacity(0.7 + _wifiAnimation.value * 0.3),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _logout,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
                              ),
                              border: Border.all(color: Colors.red.withOpacity(0.4)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.logout, color: Colors.red, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                StudentInfoCard(
                  dept: student?.branch ?? 'Unknown',
                  section: section,
                  semester: semester,
                  batch: batch,
                ),
                const SizedBox(height: 30),
                AttendanceScreen(
                  refreshCallback: () {
                    if (_isRefreshing) {
                      setState(() => _isRefreshing = false);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}