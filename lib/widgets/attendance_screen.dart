import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/services/api_service.dart';
import '/widgets/glass_card.dart';
import '/screens/daily_attendance_screen.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

class AttendanceScreen extends StatefulWidget {
  final VoidCallback? refreshCallback;
  const AttendanceScreen({Key? key, this.refreshCallback}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with TickerProviderStateMixin {
  List<dynamic> data = [];
  Map<int, List<dynamic>> dailyAttendanceMap = {};
  bool isLoading = true;
  String error = '';
  int overallPresent = 0;
  int overallTotal = 0;
  double overallPercentage = 0.0;
  DateTimeRange? dateRange;
  String statusFilter = 'All';
  late AnimationController _animationController;
  late Animation<double> _gradientAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _gradientAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutSine),
    );
    fetchAttendance().then((_) => _animationController.forward());
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
      final attendanceData = await ApiService.fetchAttendance(token);
      setState(() {
        data = attendanceData['data'];
        overallPresent = attendanceData['overallPresent'];
        overallTotal = attendanceData['overallTotal'];
        overallPercentage = attendanceData['overallPercentage'];
        isLoading = false;
      });
      widget.refreshCallback?.call();
    } catch (e) {
      debugPrint('Attendance fetch error: $e');
      setState(() {
        error = "Error: $e";
        isLoading = false;
      });
    }
  }

  void _showAttendanceDetails(BuildContext context, Map<String, dynamic> item, GlobalKey cardKey) async {
    debugPrint('Navigating to details for course: ${item['cdata']['course_name']} (cf_id: ${item['id']})');

    final dailyAttendance = dailyAttendanceMap[item['id']] ?? await ApiService.fetchDailyAttendance(item['id']);
    setState(() {
      dailyAttendanceMap[item['id']] = dailyAttendance;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyAttendanceScreen(
          item: item,
          dailyAttendance: dailyAttendance,
        ),
      ),
    );
  }

  String attendancePercentageModifier(double value) {
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: GlassCard(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
      );
    }
    if (error.isNotEmpty) {
      return GlassCard(
        child: Text(
          error,
          style: const TextStyle(color: Colors.red, fontFamily: 'Poppins-Regular'),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (data.isEmpty) {
      return GlassCard(
        child: Text(
          "No attendance data found.",
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontFamily: 'Poppins-Regular',
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final attendanceColor = overallPercentage >= 75
        ? const Color(0xFF10B981)
        : overallPercentage >= 60
        ? const Color(0xFFF97316)
        : const Color(0xFFFF2800);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.zero,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassCard(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                height: 220,
                lightened: true,
                padding: EdgeInsets.zero,
                child: Stack(
                  children: [
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: AnimatedBuilder(
                        animation: _gradientAnimation,
                        builder: (context, child) => Container(
                          height: 220 * overallPercentage / 100 * _gradientAnimation.value,
                          decoration: BoxDecoration(
                            color: attendanceColor.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(0),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${attendancePercentageModifier(overallPercentage)}%",
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w100,
                              color: Colors.white,
                              fontFamily: 'Poppins-Regular',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Present: $overallPresent / $overallTotal",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                              fontFamily: 'Poppins-SemiBold',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              CalculateCard(
                width: (MediaQuery.of(context).size.width - 48) / 2,
                overallPresent: overallPresent,
                overallTotal: overallTotal,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: data
              .where((item) => item['cdata']['course_code'] != 'Total')
              .map((item) {
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
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Poppins-Bold'),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: percentage >= 75
                                    ? const Color(0xFF10B981)
                                    : percentage >= 60
                                    ? const Color(0xFFFF6800)
                                    : const Color(0xFFFF6800),
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
                        LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percentage >= 75
                                ? const Color(0xFF10B981)
                                : percentage >= 60
                                ? const Color(0xFFFF9900)
                                : const Color(0xFFFF9900),
                          ),
                          minHeight: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          })
              .toList(),
        ),
      ],
    );
  }
}

class CalculateCard extends StatefulWidget {
  final double width;
  final int overallPresent;
  final int overallTotal;

  const CalculateCard({
    Key? key,
    required this.width,
    required this.overallPresent,
    required this.overallTotal,
  }) : super(key: key);

  @override
  _CalculateCardState createState() => _CalculateCardState();
}

class _CalculateCardState extends State<CalculateCard> {
  double targetAttendance = 75.0;

  String calculatePercentageModifier(double value) {
    return '${value.round().toString()}%';
  }

  String calculateAttendanceGoal(int present, int total, double targetPercent) {
    if (total == 0) return "No classes recorded.";
    if (targetPercent <= 0) return "Invalid target.";
    if (targetPercent == 100) return "In your dreams, mate!";

    final target = targetPercent / 100;
    final current = present / total;

    if (target > current) {
      final lectures = ((target * total - present) / (1 - target)).ceil();
      final days = (lectures / 10).ceil();
      DateTime currentDate = DateTime(2025, 6, 11);
      int workingDays = 0;
      while (workingDays < days) {
        currentDate = currentDate.add(const Duration(days: 1));
        if (currentDate.weekday != DateTime.saturday && currentDate.weekday != DateTime.sunday) {
          workingDays++;
        }
      }
      final formattedDate = DateFormat('d MMM yyyy').format(currentDate);
      return "Need $lectures lectures (~$days days) to achieve $targetPercent%\n by $formattedDate";
    } else {
      final lectures = ((present - target * total) / target).floor();
      final days = (lectures / 10).ceil();
      if (lectures <= 0) return "Attend all to maintain $targetPercent%.";
      return "Can miss $lectures classes (~$days days) at $targetPercent%.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: widget.width,
      height: 220,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          const Text(
            'Calculate',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          SleekCircularSlider(
            appearance: CircularSliderAppearance(
              size: 100,
              customWidths: CustomSliderWidths(
                trackWidth: 12,
                progressBarWidth: 12,
                shadowWidth: 0,
              ),
              customColors: CustomSliderColors(
                trackColor: const Color(0xFFA5B4FC).withOpacity(0.2),
                progressBarColor: const Color(0xFF3B82F6),
                dotColor: Colors.white,
              ),
              infoProperties: InfoProperties(
                mainLabelStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                modifier: calculatePercentageModifier,
              ),
              startAngle: 270,
              angleRange: 360,
            ),
            min: 0,
            max: 100,
            initialValue: targetAttendance,
            onChange: (value) {
              setState(() => targetAttendance = value.clamp(0.0, 100.0).round().toDouble());
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: Text(
              calculateAttendanceGoal(widget.overallPresent, widget.overallTotal, targetAttendance),
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}