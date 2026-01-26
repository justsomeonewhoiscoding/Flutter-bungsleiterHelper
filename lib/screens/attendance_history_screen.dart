import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/attendance_dialog.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  final Training training;

  const AttendanceHistoryScreen({super.key, required this.training});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${training.name} - Anwesenh...',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: FutureBuilder<List<Attendance>>(
        future: context.read<AppProvider>().getAttendanceForTraining(
          training.id!,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final attendances = snapshot.data!;

          if (attendances.isEmpty) {
            return Center(
              child: Text(
                'Keine Einträge vorhanden',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: attendances.length,
            itemBuilder: (context, index) {
              final attendance = attendances[index];
              return _AttendanceListItem(
                training: training,
                attendance: attendance,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Manuellen Eintrag hinzufügen
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AttendanceListItem extends StatelessWidget {
  final Training training;
  final Attendance attendance;

  const _AttendanceListItem({required this.training, required this.attendance});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _editAttendance(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accentRed,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      training.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      DateFormat('dd.MM.yyyy').format(attendance.date),
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: attendance.status),
            ],
          ),
        ),
      ),
    );
  }

  void _editAttendance(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AttendanceDialog(
        title: training.name,
        date: attendance.date,
        attendance: attendance,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AttendanceStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == AttendanceStatus.pending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.textSecondary.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '?',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final isPresent = status == AttendanceStatus.present;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPresent ? AppTheme.successLight : AppTheme.errorLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPresent ? AppTheme.successColor : AppTheme.errorColor,
        ),
      ),
      child: Text(
        isPresent ? 'JA' : 'NEIN',
        style: TextStyle(
          color: isPresent ? AppTheme.successColor : AppTheme.errorColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
