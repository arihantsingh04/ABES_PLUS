import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
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

  static Future<List<dynamic>> fetchDailyAttendance(
      int cfId, {
        int page = 1,
        DateTimeRange? dateRange,
        String statusFilter = 'All',
      }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final studentId = prefs.getString('student_id') ?? '';
      debugPrint('Fetching daily attendance for cf_id: $cfId, student_id: $studentId, page: $page');
      if (token.isEmpty) {
        debugPrint('Error: No token found in SharedPreferences');
        return [];
      }
      String url =
          "https://abes.platform.simplifii.com/api/v1/cards?type=Attendance&sort_by=-datetime1&equalto___fk_student=$studentId&equalto___fk_mapped_card=$cfId&page=$page&limit=20";
      if (dateRange != null) {
        final start = DateFormat('yyyy-MM-dd').format(dateRange.start);
        final end = DateFormat('yyyy-MM-dd').format(dateRange.end);
        url += "&date_gte=$start&date_lte=$end";
      }
      if (statusFilter != 'All') {
        url += "&status=$statusFilter";
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Origin': 'https://abes.web.simplifii.com',
          'Referer': 'https://abes.web.simplifii.com/',
        },
      );
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