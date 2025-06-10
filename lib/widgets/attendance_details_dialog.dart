import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '/utils/helpers.dart';
import '/services/api_service.dart';
import '/widgets/glass_card.dart';

class AttendanceDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<dynamic> dailyAttendance;
  final Offset? initialPosition;
  final Size? initialSize;
  final Function(DateTimeRange?, String) onFilterChanged;

  const AttendanceDetailsDialog({
    Key? key,
    required this.item,
    required this.dailyAttendance,
    this.initialPosition,
    this.initialSize,
    required this.onFilterChanged,
  }) : super(key: key);

  @override
  State<AttendanceDetailsDialog> createState() => _AttendanceDetailsDialogState();
}

class _AttendanceDetailsDialogState extends State<AttendanceDetailsDialog> with TickerProviderStateMixin {
  late AnimationController _crossAnimationController;
  late Animation<double> _crossScale;
  List<dynamic> attendanceData = [];
  bool isLoadingMore = false;
  int currentPage = 1;
  bool hasMore = true;
  late ScrollController _scrollController;
  DateTimeRange? dateRange;
  String statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    attendanceData = widget.dailyAttendance;
    _crossAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _crossScale = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _crossAnimationController, curve: Curves.easeInOut),
    );
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _crossAnimationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 50 && !isLoadingMore && hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (isLoadingMore || !hasMore) return;
    setState(() => isLoadingMore = true);
    final newData = await ApiService.fetchDailyAttendance(
      widget.item['id'],
      page: currentPage + 1,
      dateRange: dateRange,
      statusFilter: statusFilter,
    );
    if (mounted) {
      setState(() {
        if (newData.isEmpty) {
          hasMore = false;
        } else {
          attendanceData.addAll(newData);
          currentPage++;
        }
        isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.6),
              ),
            ),
          ),
          SizedBox(
            width: size.width * 0.8,
            height: size.height * 0.8,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.2),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.item['cdata']['course_name']?.toString() ?? 'Unknown Course',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins-Bold',
                              color: Colors.white,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTapDown: (_) => _crossAnimationController.forward(),
                          onTapUp: (_) {
                            _crossAnimationController.reverse();
                            Navigator.pop(context);
                          },
                          onTapCancel: () => _crossAnimationController.reverse(),
                          child: ScaleTransition(
                            scale: _crossScale,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red.withOpacity(0.2),
                                border: Border.all(color: Colors.red.withOpacity(0.4)),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.red,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.2),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now(),
                                builder: (context, child) => Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: Theme.of(context).colorScheme,
                                    dialogBackgroundColor: Colors.black.withOpacity(0.8),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (picked != null) {
                                setState(() {
                                  dateRange = picked;
                                  attendanceData = []; // Reset data
                                  currentPage = 1;
                                  hasMore = true;
                                  widget.onFilterChanged(dateRange, statusFilter);
                                });
                                _loadMore();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              dateRange == null
                                  ? 'Select Date Range'
                                  : '${DateFormat('dd MMM').format(dateRange!.start)} - ${DateFormat('dd MMM').format(dateRange!.end)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins-Regular',
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: statusFilter,
                              items: ['All', 'Present', 'Absent'].map((status) {
                                return DropdownMenuItem(
                                  value: status,
                                  child: Text(
                                    status,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Poppins-Regular',
                                      fontSize: 14,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    statusFilter = value;
                                    attendanceData = []; // Reset data
                                    currentPage = 1;
                                    hasMore = true;
                                    widget.onFilterChanged(dateRange, statusFilter);
                                  });
                                  _loadMore();
                                }
                              },
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white,
                                size: 20,
                              ),
                              dropdownColor: Colors.black.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daily Attendance',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins-SemiBold',
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        Text(
                          '${attendanceData.length} Entries',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Poppins-Regular',
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: attendanceData.isEmpty
                        ? Center(
                      child: Text(
                        'No attendance data available.',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                            fontFamily: 'Poppins-Regular'),
                      ),
                    )
                        : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: attendanceData.length + (isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == attendanceData.length) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          );
                        }
                        final entry = attendanceData[index];
                        final dateFormatted = entry['date_formatted']?.toString() ?? 'N/A';
                        final parts = dateFormatted.split(' ');
                        final date = parts.isNotEmpty ? parts.last : '';
                        final time = parts.length > 1 ? parts.sublist(0, parts.length - 1).join(' ') : 'N/A';
                        final status = entry['status']?.toString() ?? 'Unknown';
                        final dateLabel = getDateLabel(date);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        dateLabel,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: 'Poppins-SemiBold',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        date,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontSize: 12,
                                          fontFamily: 'Poppins-Regular',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    time,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                      fontFamily: 'Poppins-Regular',
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: status == 'Present'
                                      ? const Color(0xFF10B981).withOpacity(0.2)
                                      : const Color(0xFFEF4444).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: status == 'Present' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Poppins-SemiBold',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}