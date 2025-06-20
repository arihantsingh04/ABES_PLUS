import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/models/quiz.dart';
import '/widgets/glass_card.dart';
import '/auth_screens.dart';

class CompletedQuizzesScreen extends StatefulWidget {
  final Map<String, dynamic>? attendanceData;
  const CompletedQuizzesScreen({super.key, this.attendanceData});

  @override
  State<CompletedQuizzesScreen> createState() => _CompletedQuizzesScreenState();
}

class _CompletedQuizzesScreenState extends State<CompletedQuizzesScreen> {
  List<Quiz> quizzes = [];
  List<Quiz> filteredQuizzes = [];
  bool isLoading = true;
  String? errorMessage;
  String sortOption = 'Newest First';
  String filterCourse = 'All Courses';
  List<String> courseOptions = ['All Courses'];

  @override
  void initState() {
    super.initState();
    print('DEBUG: Received attendanceData: ${widget.attendanceData}');
    _loadCourseOptions();
    _fetchCompletedQuizzes();
  }

  Future<void> _loadCourseOptions() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedCourses = prefs.getString('cached_courses');
    List<dynamic> courses = [];
    if (cachedCourses != null) {
      courses = jsonDecode(cachedCourses);
    } else if (widget.attendanceData?['data'] != null) {
      courses = widget.attendanceData!['data'] as List<dynamic>;
      await prefs.setString('cached_courses', jsonEncode(courses));
    }
    if (courses.isNotEmpty) {
      setState(() {
        courseOptions.addAll(courses
            .map((course) => course['cdata']?['course_name']?.toString() ?? 'Unknown')
            .toSet()
            .toList());
      });
    }
  }

  void _applySortAndFilter() {
    setState(() {
      filteredQuizzes = List.from(quizzes);
      if (filterCourse != 'All Courses') {
        filteredQuizzes = filteredQuizzes.where((quiz) {
          return quiz.masterCourseCode == _getCourseCodeForName(filterCourse);
        }).toList();
      }
      switch (sortOption) {
        case 'Newest First':
          filteredQuizzes.sort((a, b) => DateTime.parse(b.loggedInAt).compareTo(DateTime.parse(a.loggedInAt)));
          break;
        case 'Oldest First':
          filteredQuizzes.sort((a, b) => DateTime.parse(a.loggedInAt).compareTo(DateTime.parse(b.loggedInAt)));
          break;
        case 'Highest Marks':
          filteredQuizzes.sort((a, b) => b.marksObtained.compareTo(a.marksObtained));
          break;
        case 'Lowest Marks':
          filteredQuizzes.sort((a, b) => a.marksObtained.compareTo(b.marksObtained));
          break;
      }
    });
  }

  String? _getCourseCodeForName(String courseName) {
    final courses = widget.attendanceData?['data'] as List<dynamic>? ?? [];
    for (var course in courses) {
      if (course['cdata']?['course_name'] == courseName) {
        return course['cdata']?['course_code']?.toString();
      }
    }
    return null;
  }

  String? _extractPinFromQuizLink(String quizLink) {
    final regex = RegExp(r'pin=([^&]+)');
    final match = regex.firstMatch(quizLink);
    return match?.group(1);
  }

  String _formatDateTime(String raw) {
    try {
      final date = DateTime.parse(raw);
      final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      return '${date.day}-${_getMonthName(date.month)}-${date.year}, $time';
    } catch (e) {
      return raw;
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  Future<String> _getCourseName(String courseId) async {
    print('DEBUG: Fetching course name for courseId = $courseId');
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> courses = [];
    final cachedCourses = prefs.getString('cached_courses');
    print('DEBUG: cached_courses = $cachedCourses');

    if (cachedCourses != null) {
      courses = jsonDecode(cachedCourses);
      print('DEBUG: Using cached_courses = $courses');
    } else if (widget.attendanceData?['data'] != null) {
      courses = widget.attendanceData!['data'] as List<dynamic>;
      print('DEBUG: Using attendanceData.data = $courses');
      await prefs.setString('cached_courses', jsonEncode(courses));
    } else {
      print('DEBUG: Both cached_courses and attendanceData are null, fetching fresh data');
      try {
        final token = prefs.getString('token');
        if (token != null) {
          final response = await http.get(
            Uri.parse('https://abes.platform.simplifii.com/api/v1/mobile/attendance'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            courses = data['response']?['data'] as List<dynamic>? ?? [];
            await prefs.setString('cached_courses', jsonEncode(courses));
            print('DEBUG: Fetched and cached fresh courses = $courses');
          }
        }
      } catch (e) {
        print('DEBUG: Failed to fetch attendance data: $e');
      }
    }

    if (courses.isNotEmpty) {
      for (var course in courses) {
        final code = course['cdata']?['course_code']?.toString();
        if (code == courseId) {
          final name = course['cdata']?['course_name']?.toString() ?? 'Unknown Course';
          print('DEBUG: Matched courseId $courseId with name $name');
          return name;
        }
      }
    }
    print('DEBUG: No matching course found for courseId $courseId');
    return 'Course Not Enrolled';
  }

  Future<void> _fetchCompletedQuizzes() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final userPin = prefs.getString('user_pin') ?? '0000';

      if (widget.attendanceData?['data'] != null) {
        final courses = widget.attendanceData!['data'] as List<dynamic>;
        await prefs.setString('cached_courses', jsonEncode(courses));
        print('DEBUG: Cached courses from attendanceData: $courses');
      } else {
        print('DEBUG: No courses found in attendanceData.data');
      }

      if (token == null || token.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = 'No authentication token found.';
        });
        return;
      }

      final quizResponse = await http.get(
        Uri.parse('https://abes.platform.simplifii.com/api/v1/custom/myEvaluatedQuizzes'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (quizResponse.statusCode == 200) {
        final quizData = jsonDecode(quizResponse.body);
        final quizList = quizData['response']?['data'] as List<dynamic>?;

        if (quizList == null || quizList.isEmpty) {
          setState(() {
            isLoading = false;
            errorMessage = 'No completed quizzes found.';
          });
          return;
        }

        List<Quiz> tempQuizzes = [];
        for (var quizJson in quizList) {
          final quizLink = quizJson['quiz_link']?.toString() ?? '';
          final pin = _extractPinFromQuizLink(quizLink);
          final quizUniqueCode = quizJson['unique_code']?.toString();

          var quiz = Quiz.fromJson(quizJson, pin: pin, quizUniqueCode: quizUniqueCode);

          if (pin != null && quizUniqueCode != null) {
            final detailsResponse = await http.post(
              Uri.parse(
                'https://faas-blr1-8177d592.doserverless.co/api/v1/web/fn-1c23ee6f-939a-44b2-9c4e-d17970ddd644/abes/fetchQuizDetails',
              ),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'pin': pin,
                'quiz_uc': quizUniqueCode,
                'user_pin': userPin,
              }),
            );

            if (detailsResponse.statusCode == 200) {
              final detailsData = jsonDecode(detailsResponse.body);
              quiz = quiz.withDetails(detailsData);
            }
          }

          tempQuizzes.add(quiz);
        }

        setState(() {
          quizzes = tempQuizzes;
          filteredQuizzes = List.from(quizzes);
          isLoading = false;
          _applySortAndFilter();
        });
      } else {
        final errorData = jsonDecode(quizResponse.body);
        setState(() {
          isLoading = false;
          errorMessage = errorData['error'] ?? 'Failed to fetch quizzes (Status: ${quizResponse.statusCode})';
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching quizzes: ${e.toString()}';
      });
    }
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
              // Header with title and sort icon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Completed Quizzes',
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
              // Quiz list or loading/error state
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            onPressed: _fetchCompletedQuizzes,
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
                      : filteredQuizzes.isEmpty
                      ? Center(
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 60,
                            color: Colors.white.withOpacity(0.7),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No completed quizzes found.',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchCompletedQuizzes,
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
                    itemCount: filteredQuizzes.length,
                    itemBuilder: (context, index) {
                      final quiz = filteredQuizzes[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: FutureBuilder<String>(
                          future: _getCourseName(quiz.masterCourseCode),
                          builder: (context, snapshot) {
                            return QuizCard(
                              quiz: quiz,
                              courseName: snapshot.data ?? 'Loading...',
                            );
                          },
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
                  children: ['Newest First', 'Oldest First', 'Highest Marks', 'Lowest Marks']
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

class QuizCard extends StatelessWidget {
  final Quiz quiz;
  final String courseName;

  const QuizCard({
    Key? key,
    required this.quiz,
    required this.courseName,
  }) : super(key: key);

  static Color _getScoreColor(double score, double? totalMarks) {
    if (totalMarks == null || totalMarks == 0) return Colors.grey;
    final percentage = (score / totalMarks) * 100;
    if (percentage >= 80) return const Color(0xFF10B981);
    if (percentage >= 60) return const Color(0xFFF97316);
    return const Color(0xFFFF2800);
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            '$courseName (${quiz.masterCourseCode})',
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
          // Date and time with icon
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 15,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Text(
                _formatDateTime(quiz.loggedInAt),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 2x2 grid of stat cards
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  icon: Icons.star,
                  color: _getScoreColor(quiz.marksObtained, quiz.totalMarks),
                  label: 'Marks',
                  value: quiz.marksObtained.toStringAsFixed(1),
                  borderColor: _getScoreColor(quiz.marksObtained, quiz.totalMarks).withOpacity(0.3),
                  backgroundColor: _getScoreColor(quiz.marksObtained, quiz.totalMarks).withOpacity(0.1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatBox(
                  icon: Icons.check_circle,
                  color: const Color(0xFF10B981),
                  label: 'Correct',
                  value: quiz.correct.toString(),
                  borderColor: const Color(0xFF10B981).withOpacity(0.3),
                  backgroundColor: const Color(0xFF10B981).withOpacity(0.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  icon: Icons.cancel,
                  color: const Color(0xFFFF2800),
                  label: 'Incorrect',
                  value: quiz.incorrect.toString(),
                  borderColor: const Color(0xFFFF2800).withOpacity(0.3),
                  backgroundColor: const Color(0xFFFF2800).withOpacity(0.1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatBox(
                  icon: Icons.remove_circle,
                  color: Colors.grey,
                  label: 'Not Attempted',
                  value: quiz.notAttempted.toString(),
                  borderColor: Colors.grey.withOpacity(0.3),
                  backgroundColor: Colors.grey.withOpacity(0.1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String raw) {
    try {
      final date = DateTime.parse(raw);
      final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      return '${date.day}-${_getMonthName(date.month)}-${date.year}, $time';
    } catch (e) {
      return raw;
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Color borderColor;
  final Color backgroundColor;

  const _StatBox({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.borderColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}