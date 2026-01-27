import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/attendance_dialog.dart';
import '../utils/app_strings.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final Training training;

  const AttendanceHistoryScreen({super.key, required this.training});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  late Future<List<Attendance>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context
        .read<AppProvider>()
        .getAttendanceForTraining(widget.training.id!);
  }

  void _refresh() {
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.training.name} - ${strings.attendanceHistoryShort}',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
        ],
      ),
      body: FutureBuilder<List<Attendance>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final attendances = snapshot.data!;

          if (attendances.isEmpty) {
            return Center(
              child: Text(
                strings.noEntries,
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
                training: widget.training,
                attendance: attendance,
                onUpdated: _refresh,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addHistoricEntry,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addHistoricEntry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null) return;
    if (!mounted) return;

    final attendance = await context.read<AppProvider>().ensureAttendanceForTrainingDate(
          trainingId: widget.training.id!,
          date: picked,
        );

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AttendanceDialog(
        title: widget.training.name,
        date: picked,
        attendance: attendance,
      ),
    );
    _refresh();
  }
}

class _AttendanceListItem extends StatelessWidget {
  final Training training;
  final Attendance attendance;
  final VoidCallback onUpdated;

  const _AttendanceListItem({
    required this.training,
    required this.attendance,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final isPresent = attendance.status == AttendanceStatus.present;
    final isAbsent = attendance.status == AttendanceStatus.absent;
    final accentColor = isPresent
        ? AppTheme.successColor
        : isAbsent
        ? AppTheme.errorColor
        : AppTheme.textSecondary.withValues(alpha: 0.4);
    final backgroundColor = isPresent
        ? AppTheme.successLight.withValues(alpha: 0.15)
        : isAbsent
        ? AppTheme.errorLight.withValues(alpha: 0.15)
        : AppTheme.cardColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
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
                  color: accentColor,
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
                    if (isPresent && attendance.lateMinutes > 0)
                      Text(
                        strings.lateLabel(attendance.lateMinutes),
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
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

  void _editAttendance(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => AttendanceDialog(
        title: training.name,
        date: attendance.date,
        attendance: attendance,
      ),
    );
    onUpdated();
  }
}

class _StatusBadge extends StatelessWidget {
  final AttendanceStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    if (status == AttendanceStatus.pending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.textSecondary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          strings.statusOpen,
          style: const TextStyle(
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
        isPresent ? strings.yes : strings.no,
        style: TextStyle(
          color: isPresent ? AppTheme.successColor : AppTheme.errorColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
