import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '/services/api_service.dart';
import '/widgets/glass_card.dart';
import 'package:abesplus/auth_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  List<dynamic> filteredAttendance = [];
  List<dynamic> sortedRecords = [];
  List<Map<String, dynamic>> assignments = [];
  bool isLoading = false;
  String errorMessage = '';
  List<FlSpot> chartData = [];
  String statusFilter = 'All';
  DateTimeRange? dateRange;
  double totalAttendancePercentage = 0.0;
  Color chartColor = const Color(0xFF10B981);
  int presentCount = 0;
  int totalClasses = 0;

  static final todayCardDecoration = BoxDecoration(
    border: Border.all(
      color: const Color(0x4D0F57FF),
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
    filteredAttendance = dailyAttendance;
    sortedRecords = _sortRecords(dailyAttendance);
    debugPrint('Initial dailyAttendance: $dailyAttendance');
    _loadAssignments();
    if (sortedRecords.isNotEmpty) {
      _computeChartData();
    }
  }

  Future<void> _loadAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final courseId = widget.item['id'].toString();
    final assignmentsJson = prefs.getString('assignments_$courseId');
    if (assignmentsJson != null) {
      setState(() {
        assignments = List<Map<String, dynamic>>.from(jsonDecode(assignmentsJson));
        debugPrint('Loaded assignments: $assignments');
      });
    }
  }

  Future<void> _saveAssignments() async {
    final prefs = await SharedPreferences.getInstance();
    final courseId = widget.item['id'].toString();
    await prefs.setString('assignments_$courseId', jsonEncode(assignments));
    debugPrint('Saved assignments: $assignments');
  }

  List<dynamic> _sortRecords(List<dynamic> records) {
    return List.from(records)
      ..sort((a, b) {
        final aDateStr = a['date_formatted']?.toString().split(' ').last ?? '';
        final bDateStr = b['date_formatted']?.toString().split(' ').last ?? '';
        if (aDateStr.isEmpty || bDateStr.isEmpty) return 0;
        try {
          final aDate = DateFormat('dd/MMM/yyyy').parse(aDateStr);
          final bDate = DateFormat('dd/MMM/yyyy').parse(bDateStr);
          return aDate.compareTo(bDate);
        } catch (e) {
          debugPrint('Date parsing error: $e');
          return 0;
        }
      });
  }

  void _computeChartData() {
    debugPrint('Computing chart data for attendance percentage');
    debugPrint('Total dailyAttendance records: ${dailyAttendance.length}');

    final today = DateTime.now();
    final filteredRecords = dailyAttendance.where((record) {
      final dateStr = record['date_formatted']?.toString().split(' ').last ?? '';
      if (dateStr.isEmpty) return false;
      try {
        final recordDate = DateFormat('dd/MMM/yyyy').parse(dateStr);
        return !recordDate.isAfter(today);
      } catch (e) {
        debugPrint('Error parsing date $dateStr: $e');
        return false;
      }
    }).toList();

    final sortedAttendance = _sortRecords(filteredRecords);
    debugPrint('Records for chart: ${sortedAttendance.map((r) => r['date_formatted']).toList()}');

    List<FlSpot> spots = [];
    presentCount = 0;
    totalClasses = 0;

    for (int i = 0; i < sortedAttendance.length; i++) {
      final record = sortedAttendance[i];
      final status = record['status']?.toString().toLowerCase() ?? '';
      totalClasses++;
      if (status == 'present') {
        presentCount++;
      }
      final percentage = totalClasses > 0 ? (presentCount / totalClasses) * 100 : 0.0;
      debugPrint('Day ${i + 1}: ${record['date_formatted']}, Status: $status, Present: $presentCount, Total: $totalClasses, Percentage: $percentage%');
      spots.add(FlSpot(i.toDouble(), percentage));
    }

    totalAttendancePercentage = totalClasses > 0 ? (presentCount / totalClasses) * 100 : 0.0;
    debugPrint('Total attendance percentage: $totalAttendancePercentage%');

    if (totalAttendancePercentage >= 75) {
      chartColor = const Color(0xFF10B981);
    } else if (totalAttendancePercentage >= 60) {
      chartColor = const Color(0xFFF97316);
    } else {
      chartColor = const Color(0xFFFF2800);
    }

    setState(() {
      chartData = spots;
      debugPrint('Chart data computed: $spots');
    });
  }

  String calculateAttendanceGoal() {
    if (totalClasses == 0) return "No classes recorded.";
    const target = 0.75;
    final current = presentCount / totalClasses;
    final daysPerLecture = 1;
    DateTime targetDate = DateTime.now();

    if (current < target) {
      final classesNeeded = ((target * totalClasses - presentCount) / (1 - target)).ceil();
      targetDate = targetDate.add(Duration(days: classesNeeded * daysPerLecture));
      return "Need $classesNeeded lectures by ${DateFormat('d MMM').format(targetDate)} to maintain 75%";
    } else {
      final canMiss = ((presentCount - target * totalClasses) / target).floor();
      targetDate = targetDate.add(Duration(days: canMiss * daysPerLecture));
      return canMiss <= 0
          ? "Attend all classes to maintain 75%"
          : "Can miss $canMiss lectures by ${DateFormat('d MMM').format(targetDate)} to maintain 75%";
    }
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
        sortedRecords = _sortRecords(allRecords);
        filteredAttendance = _applyFilters(allRecords);
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

  List<dynamic> _applyFilters(List<dynamic> records) {
    var filtered = records;
    debugPrint('Applying filters: status=$statusFilter, dateRange=$dateRange');

    if (statusFilter != 'All') {
      filtered = filtered.where((record) {
        final status = record['status']?.toString().toLowerCase() ?? '';
        return status == statusFilter.toLowerCase();
      }).toList();
    }

    if (dateRange != null) {
      filtered = filtered.where((record) {
        final dateStr = record['date_formatted']?.toString().split(' ').last ?? '';
        if (dateStr.isEmpty) return false;
        try {
          final recordDate = DateFormat('dd/MMM/yyyy').parse(dateStr);
          return recordDate.isAfter(dateRange!.start.subtract(const Duration(days: 1))) &&
              recordDate.isBefore(dateRange!.end.add(const Duration(days: 1)));
        } catch (e) {
          debugPrint('Error parsing date $dateStr: $e');
          return false;
        }
      }).toList();
    }

    debugPrint('Filtered records: ${filtered.length}');
    return filtered;
  }

  Map<String, String> _parseDateFormatted(String? dateFormatted) {
    if (dateFormatted == null || dateFormatted.isEmpty) {
      debugPrint('Invalid date_formatted: $dateFormatted');
      return {'time': 'N/A', 'date': 'N/A'};
    }

    final regex = RegExp(r'^(\d{1,2}:\d{2}(?:AM|PM)\s*-\s*\d{1,2}:\d{2}(?:AM|PM))\s+(\d{2}/[A-Za-z]{3}/\d{4})$');
    final match = regex.firstMatch(dateFormatted);

    if (match != null) {
      final time = match.group(1) ?? 'N/A';
      final date = match.group(2) ?? 'N/A';
      debugPrint('Parsed date_formatted: $dateFormatted -> time: $time, date: $date');
      return {'time': time, 'date': date};
    }

    final parts = dateFormatted.trim().split(' ');
    if (parts.length >= 4) {
      final date = parts.last;
      final time = parts.sublist(0, parts.length - 1).join(' ');
      debugPrint('Fallback parsed: $dateFormatted -> time: $time, date: $date');
      return {'time': time, 'date': date};
    }

    debugPrint('Failed to parse date_formatted: $dateFormatted');
    return {'time': 'N/A', 'date': 'N/A'};
  }

  void _showFilterDialog() {
    String tempStatusFilter = statusFilter;
    DateTimeRange? tempDateRange = dateRange;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0E101E), Color(0xFF000000)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(16),
            lightened: true,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter dialogSetState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter Attendance',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Poppins-Bold',
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Status',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontFamily: 'Poppins-Regular',
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        value: tempStatusFilter,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF0E101E),
                        items: ['All', 'Present', 'Absent'].map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(
                              status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: 'Poppins-Regular',
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          dialogSetState(() {
                            tempStatusFilter = value!;
                          });
                        },
                        style: const TextStyle(color: Colors.white),
                        underline: Container(
                          height: 1,
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Date Range',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontFamily: 'Poppins-Regular',
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            builder: (context, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Color(0xFF0F57FF),
                                  onPrimary: Colors.white,
                                  surface: Color(0xFF0E101E),
                                  onSurface: Colors.white,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            dialogSetState(() {
                              tempDateRange = picked;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F57FF),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          tempDateRange == null
                              ? 'Select Date Range'
                              : '${DateFormat('dd MMM yyyy').format(tempDateRange!.start)} - '
                              '${DateFormat('dd MMM yyyy').format(tempDateRange!.end)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontFamily: 'Poppins-Regular',
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                statusFilter = 'All';
                                dateRange = null;
                                filteredAttendance = dailyAttendance;
                                sortedRecords = _sortRecords(dailyAttendance);
                              });
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFFFF2800),
                                fontFamily: 'Poppins-Regular',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                statusFilter = tempStatusFilter;
                                dateRange = tempDateRange;
                                filteredAttendance = _applyFilters(dailyAttendance);
                                sortedRecords = _sortRecords(filteredAttendance);
                              });
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F57FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Poppins-Regular',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showAssignmentDialog() {
    final titleController = TextEditingController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0E101E), Color(0xFF000000)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: BorderRadius.circular(16),
            lightened: true,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter dialogSetState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manage Assignments',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Poppins-Bold',
                        ),
                      ),
                      const SizedBox(height: 16),
                      assignments.isEmpty
                          ? Text(
                        'No assignments added.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                          fontFamily: 'Poppins-Regular',
                        ),
                      )
                          : SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: assignments.length,
                          itemBuilder: (context, index) {
                            final assignment = assignments[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: GlassCard(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: assignment['completed'],
                                      onChanged: (value) {
                                        dialogSetState(() {
                                          assignments[index]['completed'] = value!;
                                          _saveAssignments();
                                        });
                                        setState(() {});
                                      },
                                      activeColor: const Color(0xFF0F57FF),
                                      checkColor: Colors.white,
                                    ),
                                    Expanded(
                                      child: Text(
                                        assignment['title'],
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'Poppins-Bold',
                                          decoration: assignment['completed']
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Color(0xFFFF2800), size: 20),
                                      onPressed: () {
                                        dialogSetState(() {
                                          assignments.removeAt(index);
                                          _saveAssignments();
                                        });
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Add New Assignment',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontFamily: 'Poppins-Regular',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: 'Assignment Title',
                          labelStyle: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontFamily: 'Poppins-Regular',
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                          ),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF0F57FF)),
                          ),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins-Regular',
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              if (titleController.text.isNotEmpty) {
                                dialogSetState(() {
                                  assignments.add({
                                    'title': titleController.text,
                                    'completed': false,
                                  });
                                  _saveAssignments();
                                  titleController.clear();
                                });
                                setState(() {});
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F57FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Add Assignment',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Poppins-Regular',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Close',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontFamily: 'Poppins-Regular',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allDateLabels = _sortRecords(dailyAttendance).asMap().entries.where((entry) {
      final record = entry.value;
      final dateStr = record['date_formatted']?.toString().split(' ').last ?? '';
      if (dateStr.isEmpty) return false;
      try {
        final recordDate = DateFormat('dd/MMM/yyyy').parse(dateStr);
        return !recordDate.isAfter(DateTime.now());
      } catch (e) {
        debugPrint('Error parsing date $dateStr: $e');
        return false;
      }
    }).map((entry) {
      final index = entry.key;
      final record = entry.value;
      final dateStr = record['date_formatted']?.toString().split(' ').last ?? 'N/A';
      try {
        final date = DateFormat('dd/MMM/yyyy').parse(dateStr);
        return MapEntry(index, DateFormat('dd MMM').format(date));
      } catch (e) {
        debugPrint('Error formatting date $dateStr: $e');
        return MapEntry(index, 'N/A');
      }
    }).toList();
    debugPrint('All date labels for chart: ${allDateLabels.map((e) => e.value).toList()}');

    final totalAssignments = assignments.length;
    final completedAssignments = assignments.where((a) => a['completed']).length;
    final pendingAssignments = totalAssignments - completedAssignments;
    final completionPercentage = totalAssignments > 0 ? (completedAssignments / totalAssignments) * 100 : 0.0;
    debugPrint('Assignment stats: Total=$totalAssignments, Completed=$completedAssignments, Pending=$pendingAssignments, Percentage=$completionPercentage%');

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: isLoading && dailyAttendance.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F57FF)))
              : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Poppins-Bold',
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 16,
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
                            icon: const Icon(Icons.filter_list, color: Colors.white, size: 20),
                            onPressed: _showFilterDialog,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                              color: const Color(0xFFFF2800),
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
                                color: Color(0xFF0F57FF),
                                fontFamily: 'Poppins-Regular',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4).copyWith(top: 24),
                  child: SizedBox(
                    height: 250,
                    child: chartData.isEmpty
                        ? GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No recent attendance data available for chart.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                          fontFamily: 'Poppins-Regular',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                        : ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 250),
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true, drawVerticalLine: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 20,
                                getTitlesWidget: (value, meta) => Text(
                                  '${value.toInt()}%',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
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
                                interval: allDateLabels.length > 10 ? allDateLabels.length / 5 : 1,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();
                                  final label = allDateLabels.firstWhere(
                                        (entry) => entry.key == index,
                                    orElse: () => MapEntry(index, ''),
                                  ).value;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Transform.rotate(
                                      angle: -30 * 3.14159 / 180,
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 9,
                                          fontFamily: 'Poppins-Regular',
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                reservedSize: 48,
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
                          maxX: chartData.isEmpty ? 0 : chartData.length - 1,
                          minY: 0,
                          maxY: 100,
                          lineBarsData: [
                            LineChartBarData(
                              spots: chartData,
                              isCurved: true,
                              color: chartColor,
                              barWidth: 3,
                              dotData: FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.transparent,
                                    chartColor.withOpacity(0.5),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (LineBarSpot touchedSpot) => const Color(0xFF0E101E),
                              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                                final index = spot.x.toInt();
                                final label = allDateLabels.firstWhere(
                                      (entry) => entry.key == index,
                                  orElse: () => MapEntry(index, 'N/A'),
                                ).value;
                                return LineTooltipItem(
                                  '$label: ${spot.y.toStringAsFixed(1)}%',
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
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GlassCard(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      calculateAttendanceGoal(),
                      style: TextStyle(
                        fontSize: 14,
                        color: totalAttendancePercentage >= 75
                            ? const Color(0xFF10B981)
                            : totalAttendancePercentage >= 60
                            ? const Color(0xFFF97316)
                            : const Color(0xFFFF2800),
                        fontFamily: 'Poppins-Regular',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: filteredAttendance.isEmpty && !isLoading
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
                          'No attendance records match the filters.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                            fontFamily: 'Poppins-Regular',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _showFilterDialog,
                          child: const Text(
                            'Adjust Filters',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF0F57FF),
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
                      height: 140,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: filteredAttendance.length,
                        itemBuilder: (context, index) {
                          final record = filteredAttendance[index];
                          final recordDateStr = record['date_formatted']?.toString() ?? 'N/A';
                          final parsed = _parseDateFormatted(recordDateStr);
                          final timeStr = parsed['time']!;
                          final dateStr = parsed['date']!;
                          final status = record['status']?.toString() ?? 'N/A';
                          final parsedDate = DateTime.tryParse(dateStr.split('/').reversed.join('-')) ?? DateTime.now();
                          final isToday = parsedDate.day == DateTime.now().day &&
                              parsedDate.month == DateTime.now().month &&
                              parsedDate.year == DateTime.now().year;
                          debugPrint('Rendering card $index: Time: $timeStr, Date: $dateStr, Status: $status, isToday: $isToday');
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Container(
                              width: 200,
                              decoration: isToday ? todayCardDecoration : null,
                              child: GlassCard(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Roll No: ${record['cdata']?['roll_no'] ?? 'N/A'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.7),
                                        fontFamily: 'Poppins-Regular',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontFamily: 'Poppins-Bold',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontFamily: 'Poppins-Regular',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: status.toLowerCase() == 'present'
                                          ? presentDecoration
                                          : status.toLowerCase() == 'absent'
                                          ? absentDecoration
                                          : BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: const Color(0xFFF97316),
                                      ),
                                      child: Text(
                                        status,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          fontFamily: 'Poppins-SemiBold',
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Track Assignments',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontFamily: 'Poppins-Bold',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total: $totalAssignments',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.7),
                                          fontFamily: 'Poppins-Regular',
                                        ),
                                      ),
                                      Text(
                                        'Completed: $completedAssignments',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.7),
                                          fontFamily: 'Poppins-Regular',
                                        ),
                                      ),
                                      Text(
                                        'Pending: $pendingAssignments',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.7),
                                          fontFamily: 'Poppins-Regular',
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${completionPercentage.toStringAsFixed(1)}% Complete',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.7),
                                          fontFamily: 'Poppins-Regular',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: 120,
                                        child: LinearProgressIndicator(
                                          value: completionPercentage / 100,
                                          backgroundColor: Colors.white.withOpacity(0.2),
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            completionPercentage >= 75
                                                ? const Color(0xFF10B981)
                                                : completionPercentage >= 60
                                                ? const Color(0xFFF97316)
                                                : const Color(0xFFFF2800),
                                          ),
                                          minHeight: 8,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: FloatingActionButton(
                              onPressed: _showAssignmentDialog,
                              mini: true,
                              backgroundColor: const Color(0xFF0F57FF),
                              child: const Icon(Icons.add, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Course Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: 'Poppins-Bold',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Teacher: ${dailyAttendance.isNotEmpty ? dailyAttendance.first['faculty_name']?.toString() ?? 'Unknown' : 'Unknown'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                              fontFamily: 'Poppins-Regular',
                            ),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Subject: ${widget.item['cdata']?['course_name']?.toString() ?? 'Unknown'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                              fontFamily: 'Poppins-Regular',
                            ),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Semester: ${dailyAttendance.isNotEmpty ? dailyAttendance.first['semester']?.toString() ?? 'N/A' : 'N/A'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                              fontFamily: 'Poppins-Regular',
                            ),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Section: ${dailyAttendance.isNotEmpty ? dailyAttendance.first['section']?.toString() ?? 'N/A' : 'N/A'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.7),
                              fontFamily: 'Poppins-Regular',
                            ),
                            softWrap: true,
                            overflow: TextOverflow.visible,
                          ),
                        ],
                      ),
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
}