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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ÜbungsleiterHelper'),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Deine Trainings',
                  style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),

                // Buttons: + Training, + Event
                Row(
                  children: [
                    Expanded(
                      child: _AddButton(
                        icon: Icons.add,
                        label: 'Training',
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
                        label: 'Event',
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
                    _TrainingCard(training: training),
                  for (final event in provider.events) _EventCard(event: event),
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
            'Noch keine Trainings',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Füge dein erstes Training hinzu!',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
                          '${training.weekdaysFormatted} | ${training.startTime} Uhr – ${training.endTime} Uhr',
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
                                'letztes: ${lastAttendance.status == AttendanceStatus.present ? "JA" : "NEIN"} (${DateFormat('dd.MM.yyyy').format(lastAttendance.date)})',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (nextDate != null)
                          Text(
                            'nächstes: ${DateFormat('dd.MM.yyyy').format(nextDate)} · ${training.endTime} Uhr',
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
    final nextDate = provider.getNextTrainingDate(training);

    if (nextDate == null) return;

    // Finde den Anwesenheitseintrag für das nächste Datum
    final pendingAttendance = provider.recentAttendance.firstWhere(
      (a) =>
          a.trainingId == training.id &&
          a.date.year == nextDate.year &&
          a.date.month == nextDate.month &&
          a.date.day == nextDate.day,
      orElse: () => Attendance(
        trainingId: training.id,
        date: nextDate,
        status: AttendanceStatus.pending,
      ),
    );

    showDialog(
      context: context,
      builder: (_) => AttendanceDialog(
        title: training.name,
        date: nextDate,
        attendance: pendingAttendance,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Training löschen?'),
        content: Text(
          'Möchtest du "${training.name}" wirklich löschen? Alle Anwesenheitseinträge werden ebenfalls gelöscht.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              context.read<AppProvider>().deleteTraining(training.id!);
              Navigator.pop(ctx);
            },
            child: const Text(
              'Löschen',
              style: TextStyle(color: AppTheme.accentRed),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
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
                  Text(
                    event.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${DateFormat('dd.MM.yyyy').format(event.date)} | ${event.startTime} – ${event.endTime} Uhr',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
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
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final AttendanceStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
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
