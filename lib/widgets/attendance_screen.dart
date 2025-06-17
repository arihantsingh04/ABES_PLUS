import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/services/api_service.dart';
import '/widgets/glass_card.dart';
import '/screens/daily_attendance_screen.dart';
import 'package:flutter/services.dart'; // For haptic feedback

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
      CurvedAnimation(
          parent: _animationController, curve: Curves.easeInOutSine),
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

  void _showAttendanceDetails(BuildContext context, Map<String, dynamic> item,
      GlobalKey cardKey) async {
    debugPrint(
        'Fetching daily attendance for course: ${item['cdata']['course_name']} (cf_id: ${item['id']})');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          Center(
            child: GlassCard(
              child: CircularProgressIndicator(color: Theme
                  .of(context)
                  .colorScheme
                  .primary),
            ),
          ),
    );

    final dailyAttendance = dailyAttendanceMap[item['id']] ??
        await ApiService.fetchDailyAttendance(item['id']);
    setState(() {
      dailyAttendanceMap[item['id']] = dailyAttendance;
    });

    Navigator.pop(context);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DailyAttendanceScreen(
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
          child: CircularProgressIndicator(color: Theme
              .of(context)
              .colorScheme
              .primary),
        ),
      );
    }
    if (error.isNotEmpty) {
      return GlassCard(
        child: Text(
          error,
          style: const TextStyle(
              color: Colors.red, fontFamily: 'Poppins-Regular'),
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

    final attendanceGradient = overallPercentage >= 75
        ? const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFF00855C), Color(0xFF10B981)])
        : overallPercentage >= 60
        ? const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFFB64B00), Color(0xFFF97316)])
        : const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xFFDC2626), Color(0xFFFF2800)]);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.zero,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassCard(
                width: (MediaQuery
                    .of(context)
                    .size
                    .width - 48) / 2,
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
                        builder: (context, child) =>
                            Container(
                              height: 220 * overallPercentage / 100 *
                                  _gradientAnimation.value,
                              decoration: BoxDecoration(
                                gradient: attendanceGradient,
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
                            "${attendancePercentageModifier(
                                overallPercentage)}%",
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
                width: (MediaQuery
                    .of(context)
                    .size
                    .width - 48) / 2,
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
            final percentage = double.tryParse(
                item['attendance_summary']['Percent']?.replaceAll('%', '') ??
                    '0') ?? 0;
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
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins-Bold',
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: percentage >= 75
                                    ? const Color(0xFF10B981)
                                    : percentage >= 60
                                    ? const Color(0xFFF97316)
                                    : const Color(0xFFFF2800),
                              ),
                              child: Text(
                                "${percentage.toStringAsFixed(1)}%",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Poppins-SemiBold',
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Present: ${item['attendance_summary']['Present'] ??
                              0} / ${item['attendance_summary']['Total'] ?? 0}",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                            fontFamily: 'Poppins-Regular',
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            height: 6,
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: (percentage / 100).clamp(
                                      0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: percentage >= 75
                                          ? const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xFF006D4A),
                                          Color(0xFF00855C),
                                          Color(0xFF10B981)
                                        ],
                                      )
                                          : percentage >= 60
                                          ? const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xFF994000),
                                          Color(0xFFB64B00),
                                          Color(0xFFF97316)
                                        ],
                                      )
                                          : const LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Color(0xFFB91C1C),
                                          Color(0xFFDC2626),
                                          Color(0xFFFF2800)
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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

class _CalculateCardState extends State<CalculateCard> with SingleTickerProviderStateMixin {
  double targetAttendance = 75.0;
  late FixedExtentScrollController _scrollController;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final TextEditingController _inputController = TextEditingController();
  bool _isInputVisible = false;

  @override
  void initState() {
    super.initState();
    _scrollController = FixedExtentScrollController(initialItem: targetAttendance.round());
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _inputController.text = targetAttendance.round().toString();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _showInputDialog() {
    setState(() {
      _isInputVisible = true;
    });
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0E101E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: TextField(
          controller: _inputController,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Target Attendance (%)',
            labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Color(0xFF2C67F2)),
              borderRadius: BorderRadius.circular(10),
            ),
            suffixText: '%',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          onSubmitted: (value) => _handleInputSubmission(value),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isInputVisible = false;
              });
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            onPressed: () {
              _handleInputSubmission(_inputController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F57FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Set',style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ).then((_) => setState(() => _isInputVisible = false));
  }

  void _handleInputSubmission(String value) {
    final parsedValue = double.tryParse(value) ?? targetAttendance;
    final clampedValue = parsedValue.clamp(0.0, 100.0);
    setState(() {
      targetAttendance = clampedValue.roundToDouble(); // 1% increments
      _inputController.text = targetAttendance.round().toString();
      _scrollController.animateToItem(
        targetAttendance.round(),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
    _animationController.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  String calculatePercentageModifier(double value) {
    return '${value.round()}%';
  }

  String calculateAttendanceGoal(int present, int total) {
    if (total == 0) return "No classes.";
    if (targetAttendance <= 0 || targetAttendance >= 100) {
      return targetAttendance == 100 ? "100%? Dream on!" : "Invalid target.";
    }

    final target = targetAttendance / 100;
    final current = present / total;
    final daysPerLecture = 10; // Assuming 10 lectures per day for estimation
    DateTime targetDate = DateTime.now();

    if (current < target) {
      final lecturesNeeded = ((target * total - present) / (1 - target)).ceil();
      final daysNeeded = (lecturesNeeded / daysPerLecture).ceil();
      targetDate = targetDate.add(Duration(days: daysNeeded));
      return "Need $lecturesNeeded lectures, $daysNeeded days by ${DateFormat('d MMM').format(targetDate)}";
    } else {
      final canMiss = ((present - target * total) / target).floor();
      final daysCanMiss = (canMiss / daysPerLecture).ceil();
      targetDate = targetDate.add(Duration(days: daysCanMiss));
      return canMiss <= 0
          ? "Attend all, 0 days for $targetAttendance%"
          : "Miss $canMiss lectures, $daysCanMiss days by ${DateFormat('d MMM').format(targetDate)}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      width: widget.width,
      height: 220, // Match Overall Attendance Card height

      padding: const EdgeInsets.fromLTRB(16,20,16,0),
      lightened: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _showInputDialog,
            child: const Text(
              'Set Target',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Poppins-SemiBold',
              ),
              semanticsLabel: 'Set Target. Tap to enter target attendance percentage.',
            ),
          ),
          SizedBox(
            height: 100, // Larger slider
            child: ListWheelScrollView.useDelegate(
              controller: _scrollController,
              itemExtent: 40, // Larger items
              perspective: 0.005,
              diameterRatio: 1.5,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                setState(() {
                  targetAttendance = index.toDouble(); // 1% increments
                  _inputController.text = targetAttendance.round().toString();
                });
                _animationController.forward(from: 0);
                if ([25, 50, 75, 100].contains(targetAttendance.round())) {
                  HapticFeedback.mediumImpact();
                } else {
                  HapticFeedback.selectionClick();
                }
              },
              childDelegate: ListWheelChildBuilderDelegate(
                builder: (context, index) {
                  final value = index.toDouble();
                  final isSelected = value == targetAttendance;
                  final color = value >= 75
                      ? const Color(0xFF10B981)
                      : value >= 50
                      ? const Color(0xFFF97316)
                      : const Color(0xFFFF2800);
                  return Center(
                    child: Container(
                      height: isSelected ? 50 : 40,
                      alignment: Alignment.center,
                      width: 80, // Wider for larger items
                      decoration: isSelected
                          ? BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.6), color],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      )
                          : null,
                      child: AnimatedBuilder(
                        animation: _scaleAnimation,
                        builder: (context, child) => Transform.scale(
                          scale: isSelected ? _scaleAnimation.value : 1.0,
                          child: Text(
                            '${value.round()}%',
                            style: TextStyle(
                              fontSize: isSelected ? 20 : 16, // Larger font
                              color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                              fontFamily: 'Poppins-SemiBold',
                            ),
                            textAlign: TextAlign.center,
                            semanticsLabel: isSelected ? 'Selected: ${value.round()} percent' : '${value.round()} percent',
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: 101, // 0% to 100% in 1% steps
              ),
            ),
          ),
          SizedBox(
            height: 50, // Fit larger slider
            child: Text(
              calculateAttendanceGoal(widget.overallPresent, widget.overallTotal),
              style: TextStyle(
                fontSize: 11, // Smaller for conciseness
                color: Colors.white.withOpacity(0.7),
                fontFamily: 'Poppins-Regular',
              ),
              textAlign: TextAlign.center,
              maxLines: 2, // Tighter display
              overflow: TextOverflow.ellipsis,
              semanticsLabel: calculateAttendanceGoal(widget.overallPresent, widget.overallTotal).replaceAll('\n', ' '),
            ),
          ),
        ],
      ),
    );
  }
}