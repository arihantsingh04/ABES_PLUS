import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'auth_screens.dart';
import 'models/student.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  Student? student;
  String section = 'Unknown';
  String semester = 'Unknown';
  String batch = 'Unknown';
  bool isWifiOn = false;
  late AnimationController _wifiController;
  late Animation<double> _wifiAnimation;
  late AnimationController _avatarController;
  late Animation<double> _avatarScale;
  final GlobalKey<_AttendanceScreenState> _attendanceKey = GlobalKey<_AttendanceScreenState>();

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
    final semester = prefs.getString('semester') ?? 'Unknown';
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
      final response = await http.get(
        Uri.parse("https://abes.platform.simplifii.com/api/v1/custom/getCFMappedWithStudentID?embed_attendance_summary=1"),
        headers: {
          'Authorization': 'Bearer $token',
          'Origin': 'https://abes.web.simplifii.com',
          'Referer': 'https://abes.web.simplifii.com/',
        },
      );

      debugPrint('User info API status: ${response.statusCode}');
      debugPrint('User info API response: ${response.body}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final fetchedData = json['response']?['data'] ?? [];
        if (fetchedData.isNotEmpty) {
          final item = fetchedData[0];
          final dept = item['dept']?.toString() ?? 'Unknown';
          final section = item['section']?.toString() ?? 'Unknown';
          final semester = item['semester']?.toString() ?? 'Unknown';
          final batch = item['batch']?.toString() ?? 'Unknown';

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

          await prefs.setString('dept', dept);
          await prefs.setString('section', section);
          await prefs.setString('semester', semester);
          await prefs.setString('batch', batch);

          debugPrint('Stored user info - dept: $dept, section: $section, semester: $semester, batch: $batch');
        } else {
          debugPrint('No data found in API response');
        }
      } else {
        debugPrint('Failed to load user info: ${response.statusCode}');
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    return hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
  }

  Future<void> _refreshDashboard() async {
    await Future.wait([
      _loadUserInfo(),
      _attendanceKey.currentState?.fetchAttendance() ?? Future.value(),
    ]);
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
                              Text(_getGreeting(), style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7), fontFamily: 'Poppins-Regular')),
                              Text(firstName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Poppins-Bold')),
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
                              gradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
                              border: Border.all(color: Colors.white.withOpacity(isWifiOn ? 0.4 : 0.2)),
                              boxShadow: [
                                BoxShadow(
                                  color: isWifiOn ? Theme.of(context).colorScheme.primary.withOpacity(0.3) : Colors.transparent,
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
                              gradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
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
                AttendanceScreen(key: _attendanceKey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StudentInfoCard extends StatelessWidget {
  final String dept, section, semester, batch;
  const StudentInfoCard({
    Key? key,
    required this.dept,
    required this.section,
    required this.semester,
    required this.batch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildInfoItem(context, Icons.school, 'Department', dept),
              _buildInfoItem(context, Icons.class_, 'Section', section),
              _buildInfoItem(context, Icons.timeline, 'Semester', semester),
              _buildInfoItem(context, Icons.group, 'Batch', batch),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, IconData icon, String label, String value) {
    return GestureDetector(
      onTap: () {},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
              child: Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6), fontFamily: 'Poppins-Regular')),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins-SemiBold'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with TickerProviderStateMixin {
  List<dynamic> data = [];
  Map<int, List<dynamic>> dailyAttendanceMap = {};
  bool isLoading = true;
  String error = '';
  double targetAttendance = 75.0;
  int overallPresent = 0;
  int overallTotal = 0;
  double overallPercentage = 0.0;
  DateTimeRange? dateRange;
  String statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    fetchAttendance();
  }

  Future<void> fetchAttendance() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      debugPrint('Fetching attendance with token: $token');
      if (token.isEmpty) {
        setState(() {
          error = "No token found";
          isLoading = false;
        });
        return;
      }
      final response = await http.get(
        Uri.parse("https://abes.platform.simplifii.com/api/v1/custom/getCFMappedWithStudentID?embed_attendance_summary=1"),
        headers: {
          'Authorization': 'Bearer $token',
          'Origin': 'https://abes.web.simplifii.com',
          'Referer': 'https://abes.web.simplifii.com/',
        },
      );
      debugPrint('Attendance API status: ${response.statusCode}');
      debugPrint('Attendance API response: ${response.body}');
      if (response.statusCode == 200) {
        final fetchedData = jsonDecode(response.body)['response']['data'];
        final totalEntry = fetchedData.firstWhere(
              (item) => item['cdata']['course_code'] == 'Total',
          orElse: () => null,
        );
        setState(() {
          data = fetchedData;
          if (totalEntry != null) {
            overallPresent = totalEntry['attendance_summary']['Present'] as int? ?? 0;
            overallTotal = totalEntry['attendance_summary']['Total'] as int? ?? 0;
            overallPercentage = overallTotal > 0 ? (overallPresent / overallTotal * 100) : 0.0;
          } else {
            overallPresent = 0;
            overallTotal = 0;
            overallPercentage = 0.0;
          }
          isLoading = false;
        });
      } else {
        setState(() {
          error = "Failed to load attendance: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Attendance fetch error: $e');
      setState(() {
        error = "Error: $e";
        isLoading = false;
      });
    }
  }

  Future<List<dynamic>> fetchDailyAttendance(int cfId, {int page = 1}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final studentId = prefs.getString('student_id') ?? '';
      debugPrint('Fetching daily attendance for cf_id: $cfId, student_id: $studentId, page: $page');
      if (token.isEmpty) {
        debugPrint('Error: No token found in SharedPreferences');
        return [];
      }
      String url = "https://abes.platform.simplifii.com/api/v1/cards?type=Attendance&sort_by=-datetime1&equalto___fk_student=$studentId&equalto___fk_mapped_card=$cfId&page=$page&limit=20";
      if (dateRange != null) {
        final start = DateFormat('yyyy-MM-dd').format(dateRange!.start);
        final end = DateFormat('yyyy-MM-dd').format(dateRange!.end);
        url += "&date_gte=$start&date_lte=$end";
      }
      if (statusFilter != 'All') {
        url += "&status=$statusFilter";
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Origin': 'https://abes.web.simplifii.com',
          'Referer': 'https://abes.web.simplifii.com/',
        },
      );
      debugPrint('Daily attendance API status: ${response.statusCode}');
      debugPrint('Daily attendance API response: ${response.body}');
      if (response.statusCode == 200) {
        final List<dynamic> attendanceData = jsonDecode(response.body)['response']['data'] ?? [];
        debugPrint('Daily attendance data count: ${attendanceData.length}');
        return attendanceData;
      } else {
        debugPrint('Daily attendance API failed: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Daily attendance fetch error: $e');
      return [];
    }
  }

  void _showAttendanceDetails(BuildContext context, Map<String, dynamic> item, GlobalKey cardKey) async {
    debugPrint('Showing details for course: ${item['cdata']['course_name']} (cf_id: ${item['id']})');

    final dailyAttendance = dailyAttendanceMap[item['id']] ?? await fetchDailyAttendance(item['id']);
    setState(() {
      dailyAttendanceMap[item['id']] = dailyAttendance;
    });

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => AttendanceDetailsDialog(
        item: item,
        dailyAttendance: dailyAttendance,
        onFilterChanged: (newDateRange, newStatus) {
          setState(() {
            dateRange = newDateRange;
            statusFilter = newStatus;
            dailyAttendanceMap[item['id']] = []; // Reset to trigger refetch
          });
        },
      ),
    );
  }
  LinearGradient _getProgressGradient(double percentage) {
    if (percentage >= 75) {
      return const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]);
    } else if (percentage >= 60) {
      return const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFEA580C)]);
    } else {
      return const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]);
    }
  }

  String _calculateAttendanceGoal() {
    final currentPercentage = overallPercentage;
    if (currentPercentage >= targetAttendance) {
      final classesCanMiss = ((overallPresent * 100 / targetAttendance) - overallTotal).floor();
      return classesCanMiss > 0 ? 'Can miss $classesCanMiss classes' : 'At target';
    } else {
      final classesNeeded = ((targetAttendance * overallTotal / 100) - overallPresent).ceil();
      return classesNeeded > 0 ? 'Attend $classesNeeded classes' : 'At target';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: GlassCard(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)));
    }
    if (error.isNotEmpty) {
      return GlassCard(child: Text(error, style: TextStyle(color: Colors.red, fontFamily: 'Poppins-Regular'), textAlign: TextAlign.center));
    }
    if (data.isEmpty) {
      return GlassCard(child: Text("No attendance data found.", style: TextStyle(color: Colors.white.withOpacity(0.7), fontFamily: 'Poppins-Regular'), textAlign: TextAlign.center));
    }

    return Column(
      children: [
        GlassCard(
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: overallPercentage / 100),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      builder: (context, value, child) => CircularProgressIndicator(
                        value: value,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          overallPercentage >= 75 ? const Color(0xFF10B981) : overallPercentage >= 60 ? const Color(0xFFF97316) : const Color(0xFFEF4444),
                        ),
                        strokeWidth: 8,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("${overallPercentage.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Poppins-Bold')),
                      Text(
                        overallPercentage >= 75 ? "Good" : "Low",
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7), fontFamily: 'Poppins-Regular'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "Present: $overallPresent / $overallTotal",
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7), fontFamily: 'Poppins-Regular'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Target:', style: TextStyle(fontSize: 14, fontFamily: 'Poppins-Regular')),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 150,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 8,
                        activeTrackColor: Theme.of(context).colorScheme.primary,
                        inactiveTrackColor: Colors.white.withOpacity(0.2),
                        thumbColor: Theme.of(context).colorScheme.primary,
                        overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        trackShape: RoundedRectSliderTrackShape(),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 2),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                      ),
                      child: Slider(
                        value: targetAttendance,
                        min: 50,
                        max: 100,
                        divisions: 50,
                        label: '${targetAttendance.round()}%',
                        onChanged: (value) => setState(() => targetAttendance = value),
                      ),
                    ),
                  ),
                  Text('${targetAttendance.round()}%', style: TextStyle(fontSize: 14, fontFamily: 'Poppins-Regular')),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _calculateAttendanceGoal(),
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7), fontFamily: 'Poppins-Regular'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ...data.where((item) => item['cdata']['course_code'] != 'Total').map((item) {
          final percentage = double.tryParse(item['attendance_summary']['Percent']?.replaceAll('%', '') ?? '0') ?? 0;
          final GlobalKey cardKey = GlobalKey();
          return Hero(
            tag: 'attendance-card-${item['id']}',
            child: GestureDetector(
              key: cardKey,
              onTap: () => _showAttendanceDetails(context, item, cardKey),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['cdata']['course_name'] ?? '',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Poppins-Bold'),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: _getProgressGradient(percentage),
                            ),
                            child: Text(
                              "${percentage.toStringAsFixed(1)}%",
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins-SemiBold'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Present: ${item['attendance_summary']['Present'] ?? 0} / ${item['attendance_summary']['Total'] ?? 0}",
                        style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7), fontFamily: 'Poppins-Regular'),
                      ),
                      const SizedBox(height: 12),
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0, end: percentage / 100),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        builder: (context, value, child) => LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percentage >= 75 ? const Color(0xFF10B981) : percentage >= 60 ? const Color(0xFFF97316) : const Color(0xFFEF4444),
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}

class AttendanceDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<dynamic> dailyAttendance;
  final Offset? initialPosition;
  final Size? initialSize;
  final Function(DateTimeRange?, String) onFilterChanged;

  const AttendanceDetailsDialog({
    Key? key,
    required this.item,
    required this.dailyAttendance,
    this.initialPosition,
    this.initialSize,
    required this.onFilterChanged,
  }) : super(key: key);

  @override
  State<AttendanceDetailsDialog> createState() => _AttendanceDetailsDialogState();
}

class _AttendanceDetailsDialogState extends State<AttendanceDetailsDialog> with TickerProviderStateMixin {
  late AnimationController _crossAnimationController;
  late Animation<double> _crossScale;
  List<dynamic> attendanceData = [];
  bool isLoadingMore = false;
  int currentPage = 1;
  bool hasMore = true;
  late ScrollController _scrollController;
  DateTimeRange? dateRange;
  String statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    attendanceData = widget.dailyAttendance;
    _crossAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _crossScale = Tween<double>(begin: 1.0, end: 0.8).animate(CurvedAnimation(parent: _crossAnimationController, curve: Curves.easeInOut));
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _crossAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50 && !isLoadingMore && hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (isLoadingMore || !hasMore) return;
    setState(() => isLoadingMore = true);
    final newData = await context.findAncestorStateOfType<_AttendanceScreenState>()!.fetchDailyAttendance(widget.item['id'], page: currentPage + 1);
    if (mounted) {
      setState(() {
        if (newData.isEmpty) {
          hasMore = false;
        } else {
          attendanceData.addAll(newData);
          currentPage++;
        }
        isLoadingMore = false;
      });
    }
  }

  String _getDateLabel(String dateStr) {
    try {
      final date = DateFormat('dd/MMM/yyyy').parse(dateStr);
      final today = DateTime(2025, 6, 9); // System date: June 09, 2025
      final yesterday = today.subtract(const Duration(days: 1));
      if (date.day == today.day && date.month == today.month && date.year == today.year) {
        return 'Today';
      } else if (date.day == yesterday.day && date.month == yesterday.month && date.year == yesterday.year) {
        return 'Yesterday';
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        children: [
          // Background blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.6),
              ),
            ),
          ),
          // Dialog content
          SizedBox(
            width: size.width * 0.8,
            height: size.height * 0.8,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: Course name and close button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.item['cdata']['course_name']?.toString() ?? 'Unknown Course',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins-Bold',
                              color: Colors.white,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTapDown: (_) => _crossAnimationController.forward(),
                          onTapUp: (_) {
                            _crossAnimationController.reverse();
                            Navigator.pop(context);
                          },
                          onTapCancel: () => _crossAnimationController.reverse(),
                          child: ScaleTransition(
                            scale: _crossScale,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red.withOpacity(0.2),
                                border: Border.all(color: Colors.red.withOpacity(0.4)),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.red,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Divider
                  Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  // Filters section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Date Range Filter
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now(),
                                builder: (context, child) => Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: Theme.of(context).colorScheme,
                                    dialogBackgroundColor: Colors.black.withOpacity(0.8),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setState(() {
                                  dateRange = picked;
                                  widget.onFilterChanged(dateRange, statusFilter);
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              dateRange == null
                                  ? 'Select Date Range'
                                  : '${DateFormat('dd MMM').format(dateRange!.start)} - ${DateFormat('dd MMM').format(dateRange!.end)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins-Regular',
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Status Filter
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: statusFilter,
                              items: ['All', 'Present', 'Absent'].map((status) {
                                return DropdownMenuItem(
                                  value: status,
                                  child: Text(
                                    status,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Poppins-Regular',
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    statusFilter = value;
                                    widget.onFilterChanged(dateRange, statusFilter);
                                  });
                                }
                              },
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white,
                                size: 20,
                              ),
                              dropdownColor: Colors.black.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Attendance List Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daily Attendance',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins-SemiBold',
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        Text(
                          '${attendanceData.length} Entries',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Poppins-Regular',
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Attendance List
                  Expanded(
                    child: attendanceData.isEmpty
                        ? Center(
                      child: Text(
                        'No attendance data available.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontFamily: 'Poppins-Regular',
                          fontSize: 16,
                        ),
                      ),
                    )
                        : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: attendanceData.length + (isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == attendanceData.length) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          );
                        }
                        final entry = attendanceData[index];
                        final dateFormatted = entry['date_formatted']?.toString() ?? 'N/A';
                        final parts = dateFormatted.split(' ');
                        final date = parts.length > 2 ? parts.last : '';
                        final time = parts.length > 2 ? parts.sublist(0, parts.length - 1).join(' ') : 'N/A';
                        final status = entry['status']?.toString() ?? 'Unknown';
                        final dateLabel = _getDateLabel(date);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        dateLabel,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Poppins-SemiBold',
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        date,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'Poppins-Regular',
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    time,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'Poppins-Regular',
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: status == 'Present'
                                      ? const Color(0xFF10B981).withOpacity(0.2)
                                      : const Color(0xFFEF4444).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: status == 'Present' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins-SemiBold',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}