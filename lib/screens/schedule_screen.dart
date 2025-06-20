import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/widgets/glass_card.dart';
import 'package:abesplus/auth_screens.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<Schedule> schedules = [];
  List<Schedule> filteredSchedules = [];
  bool isLoading = true;
  String? errorMessage;
  String sortOption = 'Course Name (A-Z)';
  String filterCourse = 'All Courses';
  List<String> courseOptions = ['All Courses'];

  @override
  void initState() {
    super.initState();
    _fetchSchedule();
  }

  Future<void> _fetchSchedule() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'No authentication token found.';
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://abes.platform.simplifii.com/api/v1/custom/getMyScheduleStudent'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final scheduleList = data['response']?['data'] as List<dynamic>?;

        if (scheduleList == null || scheduleList.isEmpty) {
          setState(() {
            isLoading = false;
            errorMessage = 'No schedule available at the moment.';
          });
          return;
        }

        List<Schedule> tempSchedules = [];
        for (var scheduleJson in scheduleList) {
          final schedule = Schedule.fromJson(scheduleJson);
          if (schedule.courseName != null) {
            tempSchedules.add(schedule);
          }
        }

        setState(() {
          schedules = tempSchedules;
          filteredSchedules = List.from(schedules);
          courseOptions.addAll(schedules.map((s) => s.courseName!).toSet().toList());
          isLoading = false;
          _applySortAndFilter();
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          isLoading = false;
          errorMessage = errorData['msg'] ?? 'Failed to fetch schedule (Status: ${response.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching schedule: ${e.toString()}';
      });
    }
  }

  void _applySortAndFilter() {
    setState(() {
      filteredSchedules = List.from(schedules);
      if (filterCourse != 'All Courses') {
        filteredSchedules = filteredSchedules.where((s) => s.courseName == filterCourse).toList();
      }
      switch (sortOption) {
        case 'Course Name (A-Z)':
          filteredSchedules.sort((a, b) => a.courseName!.compareTo(b.courseName!));
          break;
        case 'Course Name (Z-A)':
          filteredSchedules.sort((a, b) => b.courseName!.compareTo(a.courseName!));
          break;
        case 'Earliest Time':
          filteredSchedules.sort((a, b) {
            final aTimes = a.days.values.expand((times) => times).toList();
            final bTimes = b.days.values.expand((times) => times).toList();
            if (aTimes.isEmpty) return 1;
            if (bTimes.isEmpty) return -1;
            final aEarliest = aTimes.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
            final bEarliest = bTimes.reduce((a, b) => a.compareTo(b) < 0 ? a : b);
            return aEarliest.compareTo(bEarliest);
          });
          break;
      }
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _FilterDialog(
        initialSortOption: sortOption,
        initialFilterCourse: filterCourse,
        courseOptions: courseOptions,
        onApply: (newSortOption, newFilterCourse) {
          setState(() {
            sortOption = newSortOption;
            filterCourse = newFilterCourse;
            _applySortAndFilter();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Schedule',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.sort, color: Colors.white.withOpacity(0.7)),
                      iconSize: 20,
                      onPressed: _showFilterDialog,
                    ),
                  ],
                ),
              ),
              // Schedule list or state
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: isLoading
                      ? Center(
                    child: GlassCard(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  )
                      : errorMessage != null
                      ? Center(
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchSchedule,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              'Retry',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      : filteredSchedules.isEmpty
                      ? Center(
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 60,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No schedule available at the moment.',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchSchedule,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              'Refresh',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredSchedules.length,
                    itemBuilder: (context, index) {
                      final schedule = filteredSchedules[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ScheduleCard(schedule: schedule),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Schedule {
  final String? name;
  final String? courseName;
  final String? facultyName;
  final int? courseId;
  final int? cfId;
  final Map<String, List<String>> days;

  Schedule({
    this.name,
    this.courseName,
    this.facultyName,
    this.courseId,
    this.cfId,
    required this.days,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    final days = <String, List<String>>{};
    for (int i = 1; i <= 30; i++) {
      final key = 'c$i';
      final value = json[key];
      if (value is String && value.contains('<div')) {
        final times = value
            .split('</div>')
            .where((s) => s.contains('color:green'))
            .map((s) => RegExp(r'(\d{2}:\d{2} - \d{2}:\d{2})').firstMatch(s)?.group(1) ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        days[key] = times;
      } else {
        days[key] = [];
      }
    }

    return Schedule(
      name: json['name']?.toString(),
      courseName: json['name_text']?.toString(),
      facultyName: json['faculty_name']?.toString(),
      courseId: json['course_id'] is int ? json['course_id'] : null,
      cfId: json['cf_id'] is int ? json['cf_id'] : null,
      days: days,
    );
  }
}

class ScheduleCard extends StatelessWidget {
  final Schedule schedule;

  const ScheduleCard({Key? key, required this.schedule}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final timeSlots = <String>[];
    for (int i = 1; i <= 7; i++) {
      final times = schedule.days['c$i'] ?? [];
      if (times.isNotEmpty) {
        final dayIndex = (i - 1) % 7;
        timeSlots.add('${daysOfWeek[dayIndex]}: ${times.join(', ')}');
      }
    }

    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course name
          Text(
            schedule.courseName!,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            softWrap: true,
          ),
          const SizedBox(height: 4),
          // Faculty
          Row(
            children: [
              Icon(
                Icons.person,
                size: 20,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Text(
                'Faculty: ${schedule.facultyName}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Time slots
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: timeSlots
                .map((slot) => Text(
              slot,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF10B981),
              ),
            ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _FilterDialog extends StatefulWidget {
  final String initialSortOption;
  final String initialFilterCourse;
  final List<String> courseOptions;
  final void Function(String, String) onApply;

  const _FilterDialog({
    required this.initialSortOption,
    required this.initialFilterCourse,
    required this.courseOptions,
    required this.onApply,
  });

  @override
  _FilterDialogState createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late String tempSortOption;
  late String tempFilterCourse;

  @override
  void initState() {
    super.initState();
    tempSortOption = widget.initialSortOption;
    tempFilterCourse = widget.initialFilterCourse;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        width: MediaQuery.of(context).size.width * 0.7,
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B2A), Color(0xFF1C2526)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          borderRadius: BorderRadius.circular(12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sort & Filter',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sort By',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: ['Course Name (A-Z)', 'Course Name (Z-A)', 'Earliest Time']
                      .map((option) => GestureDetector(
                    onTap: () {
                      print('DEBUG: Tapped sort option: $option');
                      setState(() {
                        tempSortOption = option;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: tempSortOption == option
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: tempSortOption == option
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        option,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  'Filter By Course',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: widget.courseOptions
                      .map((course) => GestureDetector(
                    onTap: () {
                      print('DEBUG: Tapped filter course: $course');
                      setState(() {
                        tempFilterCourse = course;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: tempFilterCourse == course
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: tempFilterCourse == course
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: Text(
                        course,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withOpacity(0.7)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        widget.onApply(tempSortOption, tempFilterCourse);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        'Apply',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}