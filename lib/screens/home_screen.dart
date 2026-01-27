import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'add_training_screen.dart';
import 'add_event_screen.dart';
import 'attendance_history_screen.dart';
import 'settings_screen.dart';
import '../widgets/attendance_dialog.dart';
import '../utils/app_strings.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final strings = AppStrings.of(context);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  strings.yourTrainings,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                // Buttons: + Training, + Event
                Row(
                  children: [
                    Expanded(
                      child: _AddButton(
                        icon: Icons.add,
                        label: strings.training,
                        color: AppTheme.primaryColor,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddTrainingScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AddButton(
                        icon: Icons.add,
                        label: strings.event,
                        color: AppTheme.primaryDark,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddEventScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Liste der Trainings
                if (provider.trainings.isEmpty && provider.events.isEmpty)
                  _EmptyState()
                else ...[
                  for (final training in provider.trainings)
                    Dismissible(
                      key: ValueKey('training_${training.id}'),
                      direction: DismissDirection.endToStart,
                      background: const _DismissBackground(),
                      onDismissed: (_) async {
                        final deleted =
                            await context.read<AppProvider>().deleteTrainingWithUndo(
                                  training,
                                );
                        if (!context.mounted) return;
                        final strings = AppStrings.of(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${training.name} ${strings.deleted}',
                            ),
                            action: SnackBarAction(
                              label: strings.undo,
                              onPressed: () {
                                context
                                    .read<AppProvider>()
                                    .restoreTraining(deleted);
                              },
                            ),
                          ),
                        );
                      },
                      child: _TrainingCard(training: training),
                    ),
                  for (final event in provider.events)
                    Dismissible(
                      key: ValueKey('event_${event.id}'),
                      direction: DismissDirection.endToStart,
                      background: const _DismissBackground(),
                      onDismissed: (_) async {
                        final deleted =
                            await context.read<AppProvider>().deleteEventWithUndo(
                                  event,
                                );
                        if (!context.mounted) return;
                        final strings = AppStrings.of(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${event.name} ${strings.deleted}',
                            ),
                            action: SnackBarAction(
                              label: strings.undo,
                              onPressed: () {
                                context.read<AppProvider>().restoreEvent(deleted);
                              },
                            ),
                          ),
                        );
                      },
                      child: _EventCard(event: event),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AddButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.textOnPrimary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.textOnPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.fitness_center, size: 64, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            strings.noTrainingsTitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.noTrainingsSubtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingCard extends StatelessWidget {
  final Training training;

  const _TrainingCard({required this.training});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final strings = AppStrings.of(context);
    final lastAttendance = provider.getLastAttendanceForTraining(training.id!);
    final nextDate = provider.getNextTrainingDate(training);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _showAttendanceOptions(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Rote Linie links
                  Container(
                    width: 4,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Training-Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          training.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${strings.formatWeekdays(training.weekdays)} | ${training.startTime} ${strings.timeSuffix} - ${training.endTime} ${strings.timeSuffix}',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (lastAttendance != null) ...[
                              _StatusBadge(status: lastAttendance.status),
                              const SizedBox(width: 8),
                              Text(
                                '${strings.lastLabel(lastAttendance.status == AttendanceStatus.present ? strings.yes : strings.no)} (${DateFormat('dd.MM.yyyy').format(lastAttendance.date)})',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              if (lastAttendance.status ==
                                      AttendanceStatus.present &&
                                  lastAttendance.lateMinutes > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  strings.lateLabel(
                                    lastAttendance.lateMinutes,
                                  ),
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                        if (nextDate != null)
                          Text(
                            '${strings.nextLabel(DateFormat('dd.MM.yyyy').format(nextDate))} · ${training.endTime} ${strings.timeSuffix}',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Aktions-Buttons
                  Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.history),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AttendanceHistoryScreen(training: training),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete,
                          color: AppTheme.accentRed,
                        ),
                        onPressed: () => _confirmDelete(context),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttendanceOptions(BuildContext context) {
    final provider = context.read<AppProvider>();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Attendance? latestPast;
    for (final entry in provider.recentAttendance) {
      if (entry.trainingId != training.id) continue;
      final entryDate =
          DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (entryDate.isAfter(today)) continue;
      latestPast = entry;
      break;
    }

    final targetDate = latestPast?.date ?? provider.getNextTrainingDate(training);
    if (targetDate == null) return;

    provider
        .ensureAttendanceForTrainingDate(
          trainingId: training.id!,
          date: targetDate,
        )
        .then((attendance) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (_) => AttendanceDialog(
          title: training.name,
          date: targetDate,
          attendance: attendance,
        ),
      );
    });
  }

  void _confirmDelete(BuildContext context) {
    final strings = AppStrings.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteTrainingTitle(training.name)),
        content: Text(
          strings.deleteTrainingBody(training.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<AppProvider>().deleteTraining(training.id!);
              Navigator.pop(ctx);
            },
            child: Text(
              strings.delete,
              style: const TextStyle(color: AppTheme.accentRed),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return FutureBuilder<List<Attendance>>(
      future: context.read<AppProvider>().getAttendanceForEvent(event.id!),
      builder: (context, snapshot) {
        final attendance =
            snapshot.data != null && snapshot.data!.isNotEmpty
                ? snapshot.data!.first
                : null;
        final status = attendance?.status ?? AttendanceStatus.pending;
        final statusText = status == AttendanceStatus.pending
            ? strings.statusOpen
            : status == AttendanceStatus.present
            ? strings.yes
            : strings.no;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () async {
              final provider = context.read<AppProvider>();
              final entry = attendance ??
                  await provider.ensureAttendanceForEvent(
                    eventId: event.id!,
                    date: event.date,
                  );
              if (!context.mounted) return;
              showDialog(
                context: context,
                builder: (_) => AttendanceDialog(
                  title: event.name,
                  date: event.date,
                  attendance: entry,
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                event.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryDark,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                strings.eventBadge,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('dd.MM.yyyy').format(event.date)} | ${event.startTime} - ${event.endTime} ${strings.timeSuffix}',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _StatusBadge(status: status),
                            const SizedBox(width: 8),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppTheme.accentRed),
                    onPressed: () {
                      context.read<AppProvider>().deleteEvent(event.id!);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.textSecondary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.textSecondary),
        ),
        child: Text(
          strings.statusOpen,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }
    final isPresent = status == AttendanceStatus.present;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete, color: AppTheme.errorColor),
    );
  }
}
