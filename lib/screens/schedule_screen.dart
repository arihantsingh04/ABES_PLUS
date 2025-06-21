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
  DateTime selectedDate = DateTime(2025, 6, 21);
  String? lastWorkingDay;

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
        int lastDayWithSchedule = 0;
        for (var scheduleJson in scheduleList) {
          final schedule = Schedule.fromJson(scheduleJson);
          if (schedule.courseName != null) {
            tempSchedules.add(schedule);
            for (int i = 1; i <= 30; i++) {
              if ((schedule.days['c$i'] ?? []).isNotEmpty) {
                lastDayWithSchedule = lastDayWithSchedule > i ? lastDayWithSchedule : i;
              }
            }
          }
        }

        setState(() {
          schedules = tempSchedules;
          filteredSchedules = List.from(schedules);
          courseOptions.addAll(schedules.map((s) => s.courseName!).toSet().toList());
          lastWorkingDay = lastDayWithSchedule > 0 ? 'June $lastDayWithSchedule, 2025' : null;
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
            final aTimes = (a.days['c${selectedDate.day}'] ?? []).cast<String>();
            final bTimes = (b.days['c${selectedDate.day}'] ?? []).cast<String>();
            if (aTimes.isEmpty) return 1;
            if (bTimes.isEmpty) return -1;
            final aEarliest = aTimes.reduce((a, b) => _getStartTime(a).compareTo(_getStartTime(b)) < 0 ? a : b);
            final bEarliest = bTimes.reduce((a, b) => _getStartTime(a).compareTo(_getStartTime(b)) < 0 ? a : b);
            return _getStartTime(aEarliest).compareTo(_getStartTime(bEarliest));
          });
          break;
      }
    });
  }

  String _getStartTime(String timeSlot) {
    return timeSlot.split(' - ')[0]; // e.g., "08:50" from "08:50 - 09:40"
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

  bool _isOngoingLecture(String timeSlot) {
    // Parse current time (12:38 PM IST, June 21, 2025)
    final now = DateTime.now(); // Assuming IST
    final currentHour = now.hour;
    final currentMinute = now.minute;

    // Parse time slot (e.g., "08:50 - 09:40")
    final parts = timeSlot.split(' - ');
    if (parts.length != 2) return false;

    final startTime = parts[0]; // e.g., "08:50"
    final endTime = parts[1]; // e.g., "09:40"

    try {
      final startParts = startTime.split(':').map(int.parse).toList();
      final endParts = endTime.split(':').map(int.parse).toList();

      final startHour = startParts[0];
      final startMinute = startParts[1];
      final endHour = endParts[0];
      final endMinute = endParts[1];

      // Convert to minutes for comparison
      final currentTotalMinutes = currentHour * 60 + currentMinute;
      final startTotalMinutes = startHour * 60 + startMinute;
      final endTotalMinutes = endHour * 60 + endMinute;

      // Check if current time is within the time slot
      return currentTotalMinutes >= startTotalMinutes && currentTotalMinutes <= endTotalMinutes;
    } catch (e) {
      return false; // Invalid time format
    }
  }

  double _getLectureProgress(String timeSlot) {
    // Parse current time (12:38 PM IST, June 21, 2025)
    final now = DateTime.now();
    final currentHour = now.hour;
    final currentMinute = now.minute;
    final currentTotalMinutes = currentHour * 60 + currentMinute;

    // Parse time slot (e.g., "08:50 - 09:40")
    final parts = timeSlot.split(' - ');
    if (parts.length != 2) return 0.0;

    final startTime = parts[0];
    final endTime = parts[1];

    try {
      final startParts = startTime.split(':').map(int.parse).toList();
      final endParts = endTime.split(':').map(int.parse).toList();

      final startHour = startParts[0];
      final startMinute = startParts[1];
      final endHour = endParts[0];
      final endMinute = endParts[1];

      final startTotalMinutes = startHour * 60 + startMinute;
      final endTotalMinutes = endHour * 60 + endMinute;

      // Calculate progress
      if (currentTotalMinutes < startTotalMinutes) {
        return 0.0; // Lecture hasn't started
      } else if (currentTotalMinutes > endTotalMinutes) {
        return 1.0; // Lecture has ended
      } else {
        // Lecture is ongoing
        final totalDuration = endTotalMinutes - startTotalMinutes;
        final elapsed = currentTotalMinutes - startTotalMinutes;
        return elapsed / totalDuration;
      }
    } catch (e) {
      return 0.0; // Invalid time format
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final ongoingItems = <Map<String, dynamic>>[];
    final upcomingItems = <Map<String, dynamic>>[];
    final completedItems = <Map<String, dynamic>>[];

    // Categorize schedule items
    for (var schedule in filteredSchedules) {
      final times = schedule.days['c${selectedDate.day}'] ?? [];
      for (var time in times) {
        final item = {
          'schedule': schedule,
          'time': time,
          'progress': _getLectureProgress(time),
        };
        if (_isOngoingLecture(time)) {
          ongoingItems.add(item); // Ongoing lecture
        } else if (item['progress'] == 1.0) {
          completedItems.add(item); // Completed lecture
        } else {
          upcomingItems.add(item); // Upcoming lecture
        }
      }
    }

    // Sort each category by start time
    ongoingItems.sort((a, b) => _getStartTime(a['time']).compareTo(_getStartTime(b['time'])));
    upcomingItems.sort((a, b) => _getStartTime(a['time']).compareTo(_getStartTime(b['time'])));
    completedItems.sort((a, b) => _getStartTime(a['time']).compareTo(_getStartTime(b['time'])));

    // Combine: ongoing, upcoming, completed
    final scheduleItems = [...ongoingItems, ...upcomingItems, ...completedItems];

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
              // Last working day
              if (lastWorkingDay != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassCard(
                    padding: const EdgeInsets.all(8),
                    borderRadius: BorderRadius.circular(12),
                    child: Text(
                      'Last Working Day: $lastWorkingDay',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              // Date chips
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 30,
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final date = DateTime(2025, 6, day);
                    final dayIndex = date.weekday % 7; // 0=Sun, 6=Sat
                    final isSelected = selectedDate.day == day;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedDate = DateTime(2025, 6, day);
                            _applySortAndFilter();
                          });
                        },
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          borderRadius: BorderRadius.circular(12),
                          lightened: isSelected,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                daysOfWeek[dayIndex],
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '$day',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                                  fontWeight: FontWeight.w500,
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
              const SizedBox(height: 8),
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
                      : scheduleItems.isEmpty
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
                            'No schedule for ${daysOfWeek[selectedDate.weekday % 7]}, June ${selectedDate.day}, 2025.',
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
                    itemCount: scheduleItems.length,
                    itemBuilder: (context, index) {
                      final item = scheduleItems[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ScheduleCard(
                          key: ValueKey('${item['schedule'].courseId}_${item['time']}_$index'),
                          schedule: item['schedule'],
                          time: item['time'],
                          progress: item['progress'] as double,
                        ),
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
  final String time;
  final double progress;

  const ScheduleCard({
    Key? key,
    required this.schedule,
    required this.time,
    required this.progress,
  }) : super(key: key);

  Color _getDepartmentColor(String department) {
    // Simple hash-based color generation for departments
    final hash = department.codeUnits.fold(0, (sum, char) => sum + char);
    final colors = [
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.redAccent,
    ];
    return colors[hash % colors.length].withOpacity(0.7);
  }

  @override
  Widget build(BuildContext context) {
    // Split courseName into components
    final courseParts = schedule.courseName?.split('/') ?? [];
    final hasValidParts = courseParts.length >= 5;

    // Extract components, trimming whitespace
    final department = hasValidParts ? courseParts[1].trim() : 'N/A';
    final courseCode = hasValidParts ? courseParts[2].trim() : 'N/A';
    final courseTitle = hasValidParts ? courseParts[3].trim() : (schedule.courseName ?? 'N/A');
    final coursenameparts = courseCode?.trim().split(' ') ?? [];
    final ccp1 = coursenameparts.isNotEmpty ? coursenameparts[0] : 'N/A';
    final ccp2 = coursenameparts.length > 1 ? coursenameparts.sublist(1).join(' ') : 'N/A';
    return Stack(
      children: [
        // Progress background
        Positioned.fill(
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.all(0),
          borderRadius: BorderRadius.circular(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Color-coded department bar
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: _getDepartmentColor(department),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject Name
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              ccp2,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Course Code
                      Padding(
                        padding: const EdgeInsets.only(),
                        child: Row(
                          children: [
                            Icon(
                              Icons.code,
                              size: 16,
                              color: Colors.white.withOpacity(0.6),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ccp1,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Faculty Name
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              schedule.facultyName ?? 'N/A',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Timing
                      GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        borderRadius: BorderRadius.circular(12),
                        lightened: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              time,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
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
      ],
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
    final sortOptions = ['Course Name (A-Z)', 'Course Name (Z-A)', 'Earliest Time'];

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
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 16),
                Text(
                  'Sort By',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sortOptions.map((option) {
                    final isSelected = tempSortOption == option;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          tempSortOption = option;
                        });
                      },
                      child: GlassCard(
                        borderRadius: BorderRadius.circular(12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        lightened: isSelected,
                        child: Text(
                          option,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Filter By Course',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.courseOptions.map((course) {
                    final isSelected = tempFilterCourse == course;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          tempFilterCourse = course;
                        });
                      },
                      child: GlassCard(
                        borderRadius: BorderRadius.circular(12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        lightened: isSelected,
                        child: Text(
                          course,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
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