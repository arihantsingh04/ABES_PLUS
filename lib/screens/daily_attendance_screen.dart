import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '/services/api_service.dart';
import '/widgets/glass_card.dart';
import 'package:abesplus/auth_screens.dart';

class DailyAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<dynamic> dailyAttendance;

  const DailyAttendanceScreen({
    Key? key,
    required this.item,
    required this.dailyAttendance,
  }) : super(key: key);

  @override
  State<DailyAttendanceScreen> createState() => _DailyAttendanceScreenState();
}

class _DailyAttendanceScreenState extends State<DailyAttendanceScreen> {
  List<dynamic> dailyAttendance = [];
  bool isLoading = false;
  String errorMessage = '';
  List<FlSpot> chartData = [];

  // Constants for BoxDecoration
  static final todayCardDecoration = BoxDecoration(
    border: Border.all(
      color: const Color(0x4D3B82F6), // Blue accent with 0.3 opacity
      width: 1,
    ),
    borderRadius: BorderRadius.circular(12),
  );
  static final presentDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    color: const Color(0xFF10B981),
  );
  static final absentDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    color: const Color(0xFFFF2800),
  );

  @override
  void initState() {
    super.initState();
    dailyAttendance = widget.dailyAttendance.isNotEmpty ? widget.dailyAttendance : [];
    debugPrint('Initial dailyAttendance: $dailyAttendance');

    // Fetch data immediately
    _fetchData();

    // Compute chart data after initial fetch
    _computeChartData();
  }

  void _computeChartData() {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 6));
    List<FlSpot> spots = [];

    for (int i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      final recordsForDay = dailyAttendance.where((record) {
        final recordDateStr = record['date_formatted']?.toString() ?? '';
        final dateParts = recordDateStr.split(' ').last;
        final recordDate = DateTime.tryParse(dateParts.split('/').reversed.join('-')) ?? DateTime(2025, 1, 1);
        return recordDate.day == date.day &&
            recordDate.month == date.month &&
            recordDate.year == date.year;
      }).toList();

      double presentPercentage = 0;
      if (recordsForDay.isNotEmpty) {
        final presentCount = recordsForDay
            .where((record) => (record['status']?.toString().toLowerCase() ?? '') == 'present')
            .length;
        presentPercentage = (presentCount / recordsForDay.length) * 100;
      }
      spots.add(FlSpot(i.toDouble(), presentPercentage));
    }

    setState(() {
      chartData = spots;
    });
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });
    debugPrint('Fetching daily attendance for courseId=${widget.item['id']}');
    try {
      final String courseId = widget.item['id'].toString();
      final allRecords = await ApiService.fetchDailyAttendance(courseId);

      setState(() {
        dailyAttendance = allRecords;
        isLoading = false;
        _computeChartData();
      });
    } catch (e) {
      debugPrint('Fetch daily attendance error: $e');
      setState(() {
        errorMessage = 'Failed to load attendance data: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 6));
    final dateLabels = List.generate(7, (index) {
      final date = startDate.add(Duration(days: index));
      return DateFormat('dd MMM').format(date);
    });

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: isLoading && dailyAttendance.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
              : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                SizedBox(
                  height: 60,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 16,
                        top: 16,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.symmetric(
                              horizontal: BorderSide(color: Colors.white, width: 0.3),
                              vertical: BorderSide(color: Colors.white, width: 0.3),
                            ),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 16),
                          child: Text(
                            widget.item['cdata']?['course_name'] ?? 'Course',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Poppins-Bold',
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Error Message
                if (errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          Text(
                            errorMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red.withOpacity(0.7),
                              fontFamily: 'Poppins-Regular',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _fetchData,
                            child: const Text(
                              'Retry',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blueAccent,
                                fontFamily: 'Poppins-Regular',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Line Chart
                if (chartData.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(top: 24),
                    child: SizedBox(
                      height: 200, // Increased height
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            horizontalInterval: 25,
                            verticalInterval: 1,
                            getDrawingHorizontalLine: _drawGridLine,
                            getDrawingVerticalLine: _drawGridLine,
                          ),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 25,
                                getTitlesWidget: (value, meta) => Text(
                                  '${value.toInt()}%',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 12,
                                    fontFamily: 'Poppins-Regular',
                                  ),
                                ),
                                reservedSize: 32,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) => Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    dateLabels[value.toInt()],
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                      fontSize: 12,
                                      fontFamily: 'Poppins-Regular',
                                    ),
                                  ),
                                ),
                                reservedSize: 32,
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: 6,
                          minY: 0,
                          maxY: 100,
                          lineBarsData: [
                            LineChartBarData(
                              spots: chartData,
                              isCurved: true,
                              color: Colors.blueAccent,
                              barWidth: 2,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                color: Colors.blueAccent.withOpacity(0.1),
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                                return LineTooltipItem(
                                  '${dateLabels[spot.x.toInt()]}: ${spot.y.toStringAsFixed(0)}%',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFamily: 'Poppins-Regular',
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Horizontal Attendance Cards with Fade Effect
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: dailyAttendance.isEmpty && !isLoading
                      ? GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Colors.white70,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No attendance records found.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                            fontFamily: 'Poppins-Regular',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _fetchData,
                          child: const Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blueAccent,
                              fontFamily: 'Poppins-Regular',
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      : ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black,
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black,
                        ],
                        stops: [0.0, 0.05, 0.95, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstOut,
                    child: SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: dailyAttendance.length,
                        itemBuilder: (context, index) {
                          final record = dailyAttendance[index];
                          final recordDateStr = record['date_formatted']?.toString() ?? '';
                          final dateParts = recordDateStr.split(' ').last;
                          final recordDate = DateTime.tryParse(dateParts.split('/').reversed.join('-')) ?? DateTime.now();
                          final isToday = recordDate.day == now.day &&
                              recordDate.month == now.month &&
                              recordDate.year == now.year;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Container(
                              width: 200,
                              decoration: isToday ? todayCardDecoration : null,
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      record['date_formatted']?.toString() ?? 'N/A',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontFamily: 'Poppins-Bold',
                                      ),
                                    ),
                                    Text(
                                      'Roll No: ${record['cdata']?['roll_no'] ?? 'N/A'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.7),
                                        fontFamily: 'Poppins-Regular',
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: (record['status']?.toString().toLowerCase() ?? '') == 'present'
                                            ? presentDecoration
                                            : absentDecoration,
                                        child: Text(
                                          record['status']?.toString() ?? 'N/A',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            fontFamily: 'Poppins-SemiBold',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // Teacher and Subject Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Teacher',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Poppins-Bold',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                dailyAttendance.isNotEmpty
                                    ? dailyAttendance.first['faculty_name']?.toString() ?? 'Unknown'
                                    : 'Unknown',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontFamily: 'Poppins-Regular',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Subject Details',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Poppins-Bold',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.item['cdata']?['course_name']?.toString() ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white,
                                  fontFamily: 'Poppins-Regular',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Semester: ${dailyAttendance.isNotEmpty ? dailyAttendance.first['semester']?.toString() ?? 'N/A' : 'N/A'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                  fontFamily: 'Poppins-Regular',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Section: ${dailyAttendance.isNotEmpty ? dailyAttendance.first['section']?.toString() ?? 'N/A' : 'N/A'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.7),
                                  fontFamily: 'Poppins-Regular',
                                ),
                              ),
                            ],
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
  }

  FlLine _drawGridLine(double value) {
    return FlLine(
      color: Colors.white.withOpacity(0.3),
      strokeWidth: 1,
    );
  }
}