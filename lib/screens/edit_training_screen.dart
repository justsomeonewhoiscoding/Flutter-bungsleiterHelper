import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

class EditTrainingScreen extends StatefulWidget {
  final Training training;
  const EditTrainingScreen({super.key, required this.training});

  @override
  State<EditTrainingScreen> createState() => _EditTrainingScreenState();
}

class _EditTrainingScreenState extends State<EditTrainingScreen> {
  late final TextEditingController _nameController;
  late final Set<int> _selectedWeekdays;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  DateTime? _effectiveDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.training.name);
    _selectedWeekdays = widget.training.weekdays.toSet();
    _startTime = _parseTime(widget.training.startTime);
    _endTime = _parseTime(widget.training.endTime);
    final now = DateTime.now();
    _effectiveDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.read(context);
    final weekdayLabels = strings.weekdayShort;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(strings.editTrainingTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: strings.trainingNameHint,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: GestureDetector(
                  onTap: _selectEffectiveDate,
                  child: Row(
                    children: [
                      Text(
                        _effectiveDate != null
                            ? _formatDate(_effectiveDate!)
                            : strings.effectiveFromLabel,
                        style: TextStyle(
                          color: _effectiveDate != null
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.calendar_today,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.weekdaysLabel,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(7, (index) {
                        final weekday = index + 1;
                        final isSelected = _selectedWeekdays.contains(weekday);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedWeekdays.remove(weekday);
                              } else {
                                _selectedWeekdays.add(weekday);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              weekdayLabels[index],
                              style: TextStyle(
                                color: isSelected
                                    ? AppTheme.textOnPrimary
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TimeSelector(
                        label: strings.startTimeLabel,
                        time: _startTime,
                        onTap: () => _selectTime(true),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(
                        Icons.access_time,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Expanded(
                      child: _TimeSelector(
                        label: strings.endTimeLabel,
                        time: _endTime,
                        onTap: () => _selectTime(false),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _canSave ? _save : null,
            child: Text(strings.save),
          ),
        ),
      ),
    );
  }

  bool get _canSave =>
      _nameController.text.isNotEmpty &&
      _selectedWeekdays.isNotEmpty &&
      _startTime != null &&
      _endTime != null &&
      _effectiveDate != null;

  Future<void> _selectEffectiveDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _effectiveDate = picked;
    });
  }

  Future<void> _selectTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? const TimeOfDay(hour: 18, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 19, minute: 30)),
    );

    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  void _save() {
    final strings = AppStrings.read(context);
    if (_nameController.text.isEmpty ||
        _startTime == null ||
        _endTime == null ||
        _effectiveDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.validationMissingFields)),
      );
      return;
    }
    if (_selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.validationSelectWeekday)),
      );
      return;
    }

    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.validationEndAfterStart)),
      );
      return;
    }

    final updated = widget.training.copyWith(
      name: _nameController.text,
      weekdays: _selectedWeekdays.toList()..sort(),
      startTime: _formatTime(_startTime!),
      endTime: _formatTime(_endTime!),
    );

    context.read<AppProvider>().updateTrainingEffective(
      training: updated,
      effectiveDate: _effectiveDate!,
    );
    Navigator.pop(context);
  }
}

class _TimeSelector extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;

  const _TimeSelector({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Text(
            time != null
                ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
                : label,
            style: TextStyle(
              color: time != null
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          const Icon(Icons.access_time_outlined, color: AppTheme.textSecondary),
        ],
      ),
    );
  }
}
