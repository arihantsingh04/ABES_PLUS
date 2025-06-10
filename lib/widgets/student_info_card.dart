import 'package:flutter/material.dart';

import 'glass_card.dart';

class StudentInfoCard extends StatelessWidget {
  final String dept, section, semester, batch;
  const StudentInfoCard({
    Key? key,
    required this.dept,
    required this.section,
    required this.semester,
    required this.batch,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildInfoItem(context, Icons.school, 'Department', dept),
              _buildInfoItem(context, Icons.class_, 'Section', section),
              _buildInfoItem(context, Icons.timeline, 'Semester', semester),
              _buildInfoItem(context, Icons.group, 'Batch', batch),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(BuildContext context, IconData icon, String label, String value) {
    return GestureDetector(
      onTap: () {},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
              child: Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6), fontFamily: 'Poppins-Regular')),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'Poppins-SemiBold'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}