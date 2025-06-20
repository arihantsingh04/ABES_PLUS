import 'dart:convert';

class Quiz {
  final String masterCourseCode;
  final String studentName;
  final String admissionNumber;
  final double marksObtained;
  final int correct;
  final int incorrect;
  final int notAttempted;
  final String loggedInAt;
  final String quizLink;
  final String? pin;
  final String? quizUniqueCode;
  final double? totalMarks;
  final String? courseName;
  final String? facultyName;
  final String? startTime;
  final String? endTime;

  Quiz({
    required this.masterCourseCode,
    required this.studentName,
    required this.admissionNumber,
    required this.marksObtained,
    required this.correct,
    required this.incorrect,
    required this.notAttempted,
    required this.loggedInAt,
    required this.quizLink,
    this.pin,
    this.quizUniqueCode,
    this.totalMarks,
    this.courseName,
    this.facultyName,
    this.startTime,
    this.endTime,
  });

  factory Quiz.fromJson(Map<String, dynamic> json, {String? pin, String? quizUniqueCode}) {
    return Quiz(
      masterCourseCode: json['master_course_code']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? '',
      admissionNumber: json['admission_number']?.toString() ?? '',
      marksObtained: (json['marks_obtained'] is num) ? (json['marks_obtained'] as num).toDouble() : 0.0,
      correct: (json['correct'] is num) ? (json['correct'] as num).toInt() : 0,
      incorrect: (json['incorrect'] is num) ? (json['incorrect'] as num).toInt() : 0,
      notAttempted: (json['not_attempted'] is num) ? (json['not_attempted'] as num).toInt() : 0,
      loggedInAt: json['loggedin_at']?.toString() ?? '',
      quizLink: json['quiz_link']?.toString() ?? '',
      pin: pin,
      quizUniqueCode: quizUniqueCode,
    );
  }

  Quiz withDetails(Map<String, dynamic> details) {
    final data = details['response']?['data'] ?? {};
    return Quiz(
      masterCourseCode: masterCourseCode,
      studentName: studentName,
      admissionNumber: admissionNumber,
      marksObtained: marksObtained,
      correct: correct,
      incorrect: incorrect,
      notAttempted: notAttempted,
      loggedInAt: loggedInAt,
      quizLink: quizLink,
      pin: pin,
      quizUniqueCode: quizUniqueCode,
      totalMarks: (data['total_marks'] is String) ? double.tryParse(data['total_marks']) : null,
      courseName: data['cdata']?['course_name']?.toString(),
      facultyName: data['faculty_name']?.toString(),
      startTime: data['start_time']?.toString(),
      endTime: data['end_time']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'master_course_code': masterCourseCode,
      'student_name': studentName,
      'admission_number': admissionNumber,
      'marks_obtained': marksObtained,
      'correct': correct,
      'incorrect': incorrect,
      'not_attempted': notAttempted,
      'loggedin_at': loggedInAt,
      'quiz_link': quizLink,
      'pin': pin,
      'quiz_unique_code': quizUniqueCode,
      'total_marks': totalMarks,
      'course_name': courseName,
      'faculty_name': facultyName,
      'start_time': startTime,
      'end_time': endTime,
    };
  }
}