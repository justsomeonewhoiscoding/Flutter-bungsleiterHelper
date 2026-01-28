import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

class AttendanceDialog extends StatefulWidget {
  final String title;
  final DateTime date;
  final Attendance attendance;
  final String startTime;
  final String endTime;

  const AttendanceDialog({
    super.key,
    required this.title,
    required this.date,
    required this.attendance,
    required this.startTime,
    required this.endTime,
  });

  @override
  State<AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<AttendanceDialog> {
  late AttendanceStatus _status;
  late int _lateMinutes;
  late int _leftEarlyMinutes;

  @override
  void initState() {
    super.initState();
    _status = widget.attendance.status == AttendanceStatus.pending
        ? AttendanceStatus.present
        : widget.attendance.status;
    _lateMinutes = widget.attendance.lateMinutes;
    _leftEarlyMinutes = widget.attendance.leftEarlyMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.read(context);
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: constraints.maxHeight * 0.9,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(title: widget.title),
                  const SizedBox(height: 16),
                  _InfoCard(
                    title: widget.title,
                    date: widget.date,
                    startTime: widget.startTime,
                    endTime: widget.endTime,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    strings.statusTitle,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StatusSelector(
                    selected: _status,
                    lateMinutes: _lateMinutes,
                    leftEarlyMinutes: _leftEarlyMinutes,
                    onTap: _handleStatusTap,
                  ),
                  const SizedBox(height: 16),
                  if (_status == AttendanceStatus.late)
                    _InlineNote(
                      label: strings.lateMinutesLabel,
                      value: '$_lateMinutes ${strings.minutesLabel}',
                    ),
                  if (_status == AttendanceStatus.leftEarly)
                    _InlineNote(
                      label: strings.leftEarlyMinutesLabel,
                      value: '$_leftEarlyMinutes ${strings.minutesLabel}',
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successColor,
                        foregroundColor: AppTheme.textPrimary,
                      ),
                      child: Text(strings.save),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        strings.cancel,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final provider = context.read<AppProvider>();
    if (_status == AttendanceStatus.late && _lateMinutes == 0) {
      _status = AttendanceStatus.present;
    }
    if (_status == AttendanceStatus.leftEarly && _leftEarlyMinutes == 0) {
      _status = AttendanceStatus.present;
    }
    await provider.updateAttendanceStatus(
      widget.attendance,
      _status,
      lateMinutes: _lateMinutes,
      leftEarlyMinutes: _leftEarlyMinutes,
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _handleStatusTap(AttendanceStatus status) async {
    if (status == AttendanceStatus.present ||
        status == AttendanceStatus.late) {
      final initial = status == AttendanceStatus.late ? _lateMinutes : 0;
      final minutes = await _selectMinutes(initial);
      if (!mounted || minutes == null) return;
      final safeMinutes = minutes < 0 ? 0 : minutes;
      setState(() {
        if (safeMinutes == 0) {
          _status = AttendanceStatus.present;
          _lateMinutes = 0;
        } else {
          _status = AttendanceStatus.late;
          _lateMinutes = safeMinutes;
        }
      });
      return;
    }

    if (status == AttendanceStatus.leftEarly) {
      final minutes = await _selectMinutes(_leftEarlyMinutes);
      if (!mounted || minutes == null) return;
      final safeMinutes = minutes < 0 ? 0 : minutes;
      setState(() {
        _status = AttendanceStatus.leftEarly;
        _leftEarlyMinutes = safeMinutes;
      });
      return;
    }

    setState(() {
      _status = status;
    });
  }

  Future<int?> _selectMinutes(int initialMinutes) async {
    final strings = AppStrings.read(context);
    final safeInitial = initialMinutes < 0 ? 0 : initialMinutes;
    Duration selected = Duration(minutes: safeInitial);
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.latenessTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 160,
                      child: CupertinoTimerPicker(
                        mode: CupertinoTimerPickerMode.hm,
                        initialTimerDuration: selected,
                        onTimerDurationChanged: (duration) {
                          setState(() => selected = duration);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(sheetContext, 0),
                            child: Text(strings.onTime),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(
                              sheetContext,
                              selected.inMinutes < 0 ? 0 : selected.inMinutes,
                            ),
                            child: Text(strings.apply),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String title;

  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
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
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final DateTime date;
  final String startTime;
  final String endTime;

  const _InfoCard({
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.read(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title · ${DateFormat('dd.MM.yyyy').format(date)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$startTime - $endTime ${strings.timeSuffix}',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  final AttendanceStatus selected;
  final int lateMinutes;
  final int leftEarlyMinutes;
  final ValueChanged<AttendanceStatus> onTap;

  const _StatusSelector({
    required this.selected,
    required this.lateMinutes,
    required this.leftEarlyMinutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.read(context);
    return Column(
      children: [
        _StatusOption(
          label: strings.statusOnTime,
          icon: Icons.check,
          color: AppTheme.successColor,
          selected: selected == AttendanceStatus.present,
          trailing: '0 ${strings.minutesLabel}',
          onTap: () => onTap(AttendanceStatus.present),
        ),
        const SizedBox(height: 10),
        _StatusOption(
          label: strings.statusLate,
          icon: Icons.access_time,
          color: AppTheme.warningColor,
          selected: selected == AttendanceStatus.late,
          trailing: '$lateMinutes ${strings.minutesLabel}',
          onTap: () => onTap(AttendanceStatus.late),
        ),
        const SizedBox(height: 10),
        _StatusOption(
          label: strings.statusLeftEarly,
          icon: Icons.logout,
          color: AppTheme.warningColor,
          selected: selected == AttendanceStatus.leftEarly,
          trailing: '$leftEarlyMinutes ${strings.minutesLabel}',
          onTap: () => onTap(AttendanceStatus.leftEarly),
        ),
        const SizedBox(height: 10),
        _StatusOption(
          label: strings.statusAbsent,
          icon: Icons.close,
          color: AppTheme.errorColor,
          selected: selected == AttendanceStatus.absent,
          onTap: () => onTap(AttendanceStatus.absent),
        ),
      ],
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;

  const _StatusOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.2) : AppTheme.cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : AppTheme.textSecondary.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? color : AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (trailing != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    trailing!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? color.withValues(alpha: 0.9)
                          : AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineNote extends StatelessWidget {
  final String label;
  final String value;

  const _InlineNote({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
