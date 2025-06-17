import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

String getGreeting() {
  final hour = DateTime.now().hour;
  return hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
}

String getDateLabel(String dateStr) {
  try {
    final date = DateFormat('dd/MMM/yyyy').parse(dateStr);
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    if (date.day == today.day && date.month == today.month && date.year == today.year) {
      return 'Today';
    } else if (date.day == yesterday.day && date.month == yesterday.month && date.year == yesterday.year) {
      return 'Yesterday';
    }
    return dateStr;
  } catch (e) {
    return dateStr;
  }
}

LinearGradient getProgressGradient(double percentage) {
  if (percentage >= 75) {
    return const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]);
  } else if (percentage >= 60) {
    return const LinearGradient(colors: [Color(0xFFFF6A00), Color(0xFFFF6200)]);
  } else {
    return const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFDC2626)]);
  }
}

String calculateAttendanceGoal(int overallPresent, int overallTotal, double targetAttendance) {
  final currentPercentage = overallTotal > 0 ? (overallPresent / overallTotal * 100) : 0.0;
  if (currentPercentage >= targetAttendance) {
    final classesCanMiss = ((overallPresent * 100 / targetAttendance) - overallTotal).floor();
    return classesCanMiss > 0 ? 'Can miss $classesCanMiss classes' : 'At target';
  } else {
    final classesNeeded = ((targetAttendance * overallTotal / 100) - overallPresent).ceil();
    return classesNeeded > 0 ? 'Attend $classesNeeded classes' : 'At target';
  }
}