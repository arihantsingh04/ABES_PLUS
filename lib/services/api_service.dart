import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class ApiService {
  static Future<Map<String, dynamic>?> fetchUserInfo(String token, String studentId) async {
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
          return {
            'dept': item['dept']?.toString() ?? 'Unknown',
            'section': item['section']?.toString() ?? 'Unknown',
            'semester': item['semester']?.toString() ?? 'Unknown',
            'batch': item['batch']?.toString() ?? 'Unknown',
          };
        }
        debugPrint('No data found in API response');
        return null;
      }
      debugPrint('Failed to load user info: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('User info fetch error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> fetchAttendance(String token) async {
    try {
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
        return {
          'data': fetchedData,
          'overallPresent': int.tryParse(totalEntry?['attendance_summary']?['Present']?.toString() ?? '0') ?? 0,
          'overallTotal': int.tryParse(totalEntry?['attendance_summary']?['Total']?.toString() ?? '0') ?? 0,
          'overallPercentage':
          double.tryParse(totalEntry?['attendance_summary']?['Percent']?.replaceAll('%', '') ?? '0') ?? 0.0,
        };
      }
      throw Exception('Failed to load attendance: ${response.statusCode}');
    } catch (e) {
      debugPrint('Attendance fetch error: $e');
      rethrow;
    }
  }

  static Future<List<dynamic>> fetchDailyAttendance(dynamic courseId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final studentNumber = prefs.getString('student_number') ?? '';
      debugPrint('Fetching daily attendance for course_id: $courseId, student_number: $studentNumber');

      if (token.isEmpty || studentNumber.isEmpty) {
        debugPrint('Error: Token or student number not found in SharedPreferences');
        return [];
      }

      // Convert courseId to String
      final String courseIdStr = courseId.toString();

      // Construct the URL with dynamic student number
      final url = "https://abes.platform.simplifii.com/api/v1/cards?type=Attendance&sort_by=+datetime1&equalto___fk_student=$studentNumber&equalto___cf_id=$courseIdStr&token=$token";

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Origin': 'https://abes.web.simplifii.com',
          'Referer': 'https://abes.web.simplifii.com/',
        },
      );

      debugPrint('Daily attendance API URL: $url');
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
}