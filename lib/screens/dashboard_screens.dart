import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flashy_tab_bar2/flashy_tab_bar2.dart';
import '../auth_screens.dart';
import '/models/student.dart';
import '/widgets/student_info_card.dart';
import '/widgets/attendance_screen.dart';
import '/utils/helpers.dart';
import '/services/api_service.dart';
import '/auto_wifi_login.dart';
import '/screens/quiz_screen.dart';
import '/screens/completed_quizzes_screen.dart';
import '/screens/schedule_screen.dart';
import 'dart:convert';
import 'dart:ui';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  Student? student;
  String section = 'Unknown';
  String semester = '';
  String batch = 'Unknown';
  bool isWifiOn = false;
  bool _isWifiLoading = false;
  late AnimationController _wifiController;
  late Animation<double> _wifiAnimation;
  late AnimationController _avatarController;
  late Animation<double> _avatarScale;
  bool _isRefreshing = false;
  Map<String, dynamic>? attendanceData;
  int _selectedIndex = 1; // Track selected navbar item
  bool _isDarkMode = true; // Track theme mode

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _loadUserInfo();
    _initWifiState();
    _wifiController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _wifiAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _wifiController, curve: Curves.easeInOut));
    _avatarController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _avatarScale = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _avatarController, curve: Curves.easeOut));
    _loadThemeMode();
  }

  @override
  void dispose() {
    _wifiController.dispose();
    _avatarController.dispose();
    super.dispose();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    });
  }

  Future<void> _toggleThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
      prefs.setBool('isDarkMode', _isDarkMode);
    });
    // Note: Theme change requires app-level theme update in main.dart
  }

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedStudent = prefs.getString('cached_student');
    final cachedSection = prefs.getString('cached_section');
    final cachedSemester = prefs.getString('cached_semester');
    final cachedBatch = prefs.getString('cached_batch');
    final cachedWifi = prefs.getBool('cached_wifi') ?? false;
    final cachedAttendance = prefs.getString('cached_attendance');
    final cachedCourses = prefs.getString('cached_courses');

    setState(() {
      if (cachedStudent != null) {
        student = Student.fromJson(jsonDecode(cachedStudent));
      }
      section = cachedSection ?? 'Unknown';
      semester = cachedSemester ?? '';
      batch = cachedBatch ?? 'Unknown';
      isWifiOn = cachedWifi;
      if (isWifiOn) _wifiController.forward();
      if (cachedAttendance != null) {
        attendanceData = jsonDecode(cachedAttendance);
      }
      if (cachedCourses != null) {
        print('Debug: Loaded cached_courses: $cachedCourses');
      }
    });
  }

  Future<void> _initWifiState() async {
    try {
      bool connected = await isAlreadyLoggedInToWifi();
      print("🔍 Initial Wi-Fi state check: $connected");
      setState(() {
        isWifiOn = connected;
        if (isWifiOn) {
          _wifiController.forward();
        } else {
          _wifiController.reverse();
        }
        SharedPreferences.getInstance().then((prefs) =>
            prefs.setBool('cached_wifi', connected));
      });
    } catch (e) {
      print("❌ Error checking initial Wi-Fi state: $e");
      setState(() {
        isWifiOn = false;
        _wifiController.reverse();
        SharedPreferences.getInstance().then((prefs) =>
            prefs.setBool('cached_wifi', false));
      });
    }
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
      prefs.setString('cached_student', jsonEncode(student!.toJson()));
      prefs.setString('cached_section', section);
      prefs.setString('cached_semester', semester);
      prefs.setString('cached_batch', batch);
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
          prefs.setString('cached_student', jsonEncode(student!.toJson()));
          prefs.setString('cached_section', userInfo['section']);
          prefs.setString('cached_semester', userInfo['semester']);
          prefs.setString('cached_batch', userInfo['batch']);
        });

        await prefs.setString('dept', userInfo['dept']);
        await prefs.setString('section', userInfo['section']);
        await prefs.setString('semester', userInfo['semester']);
        await prefs.setString('batch', userInfo['batch']);

        try {
          final attendance = await ApiService.fetchAttendance(token);
          setState(() {
            attendanceData = attendance;
            prefs.setString('cached_attendance', jsonEncode(attendance));
            // Cache courses from attendanceData['data']
            if (attendance?['data'] != null) {
              final courses = attendance['data'] as List<dynamic>;
              prefs.setString('cached_courses', jsonEncode(courses));
              print('Debug: Cached courses in _loadUserInfo: $courses');
            } else {
              print('Debug: No courses found in attendanceData.data');
            }
          });
        } catch (e) {
          debugPrint('Attendance fetch error: $e');
        }

        debugPrint(
            'Stored user info - dept: ${userInfo['dept']}, section: ${userInfo['section']}, semester: ${userInfo['semester']}, batch: ${userInfo['batch']}');
      } else {
        debugPrint('No data found in API response');
      }
    } catch (e) {
      debugPrint('User info fetch error: $e');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _onNavBarTap(int index) {
    setState(() {
      _selectedIndex = index;
      print('Debug: NavBar tapped, selectedIndex: $_selectedIndex');
    });
  }

  // Screens for navigation, updated dynamically with attendanceData
  List<Widget> get _screens => [
    CompletedQuizzesScreen(attendanceData: attendanceData),
    const DashboardContent(),
    const ScheduleScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0x80A0A0A),
      body: _screens[_selectedIndex], // Display the selected screen
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: const Border(top: BorderSide(color: Colors.white54, width: 1)),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 100),
            blendMode: BlendMode.srcOver,
            child: FlashyTabBar(
              backgroundColor: Colors.transparent,
              selectedIndex: _selectedIndex,
              iconSize: 24,
              showElevation: false,
              height: 55,
              onItemSelected: _onNavBarTap,
              items: [
                FlashyTabBarItem(
                  icon: _selectedIndex == 0
                      ? const SizedBox.shrink()
                      : const Icon(CupertinoIcons.checkmark_seal, color: Colors.white70),
                  title: Container(
                    padding: _selectedIndex == 0
                        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                        : null,
                    decoration: _selectedIndex == 0
                        ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                    )
                        : null,
                    child: Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _selectedIndex == 0 ? Colors.white : Colors.transparent,
                      ),
                    ),
                  ),
                  activeColor: Colors.white,
                ),
                FlashyTabBarItem(
                  icon: _selectedIndex == 1
                      ? const SizedBox.shrink()
                      : const Icon(CupertinoIcons.square_grid_3x2, color: Colors.white70),
                  title: Container(
                    padding: _selectedIndex == 1
                        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                        : null,
                    decoration: _selectedIndex == 1
                        ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                    )
                        : null,
                    child: Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _selectedIndex == 1 ? Colors.white : Colors.transparent,
                      ),
                    ),
                  ),
                  activeColor: Colors.white,
                ),
                FlashyTabBarItem(
                  icon: _selectedIndex == 2
                      ? const SizedBox.shrink()
                      : const Icon(CupertinoIcons.calendar, color: Colors.white70),
                  title: Container(
                    padding: _selectedIndex == 2
                        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                        : null,
                    decoration: _selectedIndex == 2
                        ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.white.withOpacity(0.1),
                        ],
                      ),
                    )
                        : null,
                    child: Text(
                      'Schedule',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _selectedIndex == 2 ? Colors.white : Colors.transparent,
                      ),
                    ),
                  ),
                  activeColor: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardContent extends StatefulWidget {
  const DashboardContent({super.key});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> with TickerProviderStateMixin {
  Student? student;
  String section = 'Unknown';
  String semester = '';
  String batch = '';
  bool isWifiOn = false;
  bool _isWifiLoading = false;
  late AnimationController _wifiController;
  late Animation<double> _wifiAnimation;
  late AnimationController _avatarController;
  late Animation<double> _avatarScale;
  bool _isRefreshing = false;
  Map<String, dynamic>? attendanceData;

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _loadUserInfo();
    _initWifiState();
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

  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedStudent = prefs.getString('cached_student');
    final cachedSection = prefs.getString('cached_section');
    final cachedSemester = prefs.getString('cached_semester');
    final cachedBatch = prefs.getString('cached_batch');
    final cachedWifi = prefs.getBool('cached_wifi') ?? false;
    final cachedAttendance = prefs.getString('cached_attendance');
    final cachedCourses = prefs.getString('cached_courses');

    setState(() {
      if (cachedStudent != null) {
        student = Student.fromJson(jsonDecode(cachedStudent));
      }
      section = cachedSection ?? 'Unknown';
      semester = cachedSemester ?? '';
      batch = cachedBatch ?? 'Unknown';
      isWifiOn = cachedWifi;
      if (isWifiOn) _wifiController.forward();
      if (cachedAttendance != null) {
        attendanceData = jsonDecode(cachedAttendance);
      }
      if (cachedCourses != null) {
        print('Debug: Loaded cached_courses in DashboardContent: $cachedCourses');
      }
    });
  }

  Future<void> _initWifiState() async {
    try {
      bool connected = await isAlreadyLoggedInToWifi();
      print("🔍 Initial Wi-Fi state check: $connected");
      setState(() {
        isWifiOn = connected;
        if (isWifiOn) {
          _wifiController.forward();
        } else {
          _wifiController.reverse();
        }
        SharedPreferences.getInstance().then((prefs) => prefs.setBool('cached_wifi', connected));
      });
    } catch (e) {
      print("❌ Error checking initial Wi-Fi state: $e");
      setState(() {
        isWifiOn = false;
        _wifiController.reverse();
        SharedPreferences.getInstance().then((prefs) => prefs.setBool('cached_wifi', false));
      });
    }
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
      prefs.setString('cached_student', jsonEncode(student!.toJson()));
      prefs.setString('cached_section', section);
      prefs.setString('cached_semester', semester);
      prefs.setString('cached_batch', batch);
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
          prefs.setString('cached_student', jsonEncode(student!.toJson()));
          prefs.setString('cached_section', userInfo['section']);
          prefs.setString('cached_semester', userInfo['semester']);
          prefs.setString('cached_batch', userInfo['batch']);
        });

        await prefs.setString('dept', userInfo['dept']);
        await prefs.setString('section', userInfo['section']);
        await prefs.setString('semester', userInfo['semester']);
        await prefs.setString('batch', userInfo['batch']);

        try {
          final attendance = await ApiService.fetchAttendance(token);
          setState(() {
            attendanceData = attendance;
            prefs.setString('cached_attendance', jsonEncode(attendance));
            // Cache courses from attendanceData['data']
            if (attendance?['data'] != null) {
              final courses = attendance['data'] as List<dynamic>;
              prefs.setString('cached_courses', jsonEncode(courses));
              print('Debug: Cached courses in DashboardContent _loadUserInfo: $courses');
            } else {
              print('Debug: No courses found in attendanceData.data in DashboardContent');
            }
          });
        } catch (e) {
          debugPrint('Attendance fetch error: $e');
        }

        debugPrint('Stored user info - dept: ${userInfo['dept']}, section: ${userInfo['section']}, semester: ${userInfo['semester']}, batch: ${userInfo['batch']}');
      } else {
        debugPrint('No data found in API response');
      }
    } catch (e) {
      debugPrint('User info fetch error: $e');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Future<void> _toggleWifi() async {
    if (!isWifiOn && !_isWifiLoading) {
      setState(() {
        _isWifiLoading = true;
      });

      try {
        print("🔄 Starting Wi-Fi login process...");
        final success = await checkAndAutoLoginToCollegeWifi(context);
        print("🔍 Login process result: $success");

        setState(() {
          _isWifiLoading = false;
          isWifiOn = success;
          if (success) {
            _wifiController.forward();
          } else {
            _wifiController.reverse();
          }
          SharedPreferences.getInstance().then((prefs) => prefs.setBool('cached_wifi', success));
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.white,
            behavior: SnackBarBehavior.floating,
            elevation: 6,
            duration: const Duration(seconds: 3),
            content: Row(
              children: [
                Icon(
                  success ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: success ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    success ? "Successfully logged in to ABES Wi-Fi" : "Wi-Fi login failed. Check credentials or network.",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        );
      } catch (e) {
        print("❌ Exception in _toggleWifi: $e");
        setState(() {
          _isWifiLoading = false;
          isWifiOn = false;
          _wifiController.reverse();
          SharedPreferences.getInstance().then((prefs) => prefs.setBool('cached_wifi', false));
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.white,
            behavior: SnackBarBehavior.floating,
            elevation: 6,
            duration: const Duration(seconds: 3),
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Error occurred during Wi-Fi login: ${e.toString()}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 15,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } else if (isWifiOn && !_isWifiLoading) {
      setState(() {
        isWifiOn = false;
        _wifiController.reverse();
        SharedPreferences.getInstance().then((prefs) => prefs.setBool('cached_wifi', false));
      });

      await logoutWifiCredentials();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          elevation: 6,
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                color: Colors.orange,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Wi-Fi credentials cleared",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _refreshDashboard() async {
    setState(() => _isRefreshing = true);
    await _loadUserInfo();
    await _initWifiState();
    setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final firstName = student?.name.split(" ").first ?? 'Student';
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: true,
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
                            onTap: _isWifiLoading ? null : _toggleWifi,
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
                              child: _isWifiLoading
                                  ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              )
                                  : AnimatedBuilder(
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
                  const SizedBox(height: 20),
                  StudentInfoCard(
                    dept: student?.branch ?? 'Unknown',
                    section: section,
                    semester: semester,
                    batch: batch,
                  ),
                  const SizedBox(height: 15),
                  AttendanceScreen(
                    cachedAttendance: attendanceData,
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
      ),
    );
  }
}