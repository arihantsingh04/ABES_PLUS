import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/utils/helpers.dart';
import '/services/api_service.dart';
import '/widgets/glass_card.dart';
import '/widgets/attendance_details_dialog.dart';

class AttendanceScreen extends StatefulWidget {
  final VoidCallback? refreshCallback; // Callback for refresh completion
  const AttendanceScreen({Key? key, this.refreshCallback}) : super(key: key);

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
      final attendanceData = await ApiService.fetchAttendance(token);
      setState(() {
        data = attendanceData['data'];
        overallPresent = attendanceData['overallPresent'];
        overallTotal = attendanceData['overallTotal'];
        overallPercentage = attendanceData['overallPercentage'];
        isLoading = false;
      });
      widget.refreshCallback?.call(); // Notify refresh completion
    } catch (e) {
      debugPrint('Attendance fetch error: $e');
      setState(() {
        error = "Error: $e";
        isLoading = false;
      });
    }
  }

  void _showAttendanceDetails(BuildContext context, Map<String, dynamic> item, GlobalKey cardKey) async {
    debugPrint('Showing details for course: ${item['cdata']['course_name']} (cf_id: ${item['id']})');

    final dailyAttendance = dailyAttendanceMap[item['id']] ??
        await ApiService.fetchDailyAttendance(item['id'], dateRange: dateRange, statusFilter: statusFilter);
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
          style: TextStyle(color: Colors.red, fontFamily: 'Poppins-Regular'),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (data.isEmpty) {
      return GlassCard(
        child: Text(
          "No attendance data found.",
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontFamily: 'Poppins-Regular'),
          textAlign: TextAlign.center,
        ),
      );
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
                          overallPercentage >= 75
                              ? const Color(0xFF10B981)
                              : overallPercentage >= 60
                              ? const Color(0xFFF97316)
                              : const Color(0xFFEF4444),
                        ),
                        strokeWidth: 8,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${overallPercentage.toStringAsFixed(1)}%",
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Poppins-Bold'),
                      ),
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
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7), fontFamily: 'Poppins-SemiBold'),
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
                calculateAttendanceGoal(overallPresent, overallTotal, targetAttendance),
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
                              gradient: getProgressGradient(percentage),
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
                            percentage >= 75
                                ? const Color(0xFF10B981)
                                : percentage >= 60
                                ? const Color(0xFFF97316)
                                : const Color(0xFFEF4444),
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