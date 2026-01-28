import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../utils/app_strings.dart';

class AppProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  // State
  List<Training> _trainings = [];
  List<Event> _events = [];
  List<Attendance> _recentAttendance = [];
  AppSettings _settings = AppSettings();
  bool _isLoading = false;

  // Getters
  List<Training> get trainings => _trainings;
  List<Event> get events => _events;
  List<Attendance> get recentAttendance => _recentAttendance;
  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

  // Initialisierung
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await Future.wait([
      loadTrainings(),
      loadEvents(),
      loadRecentAttendance(),
      loadSettings(),
    ]);

    await NotificationService().requestPermission();
    await PlankoService().ensureCurrentPlankoExists(
      customTemplatePath: _settings.customTemplatePath,
    );
    await _backfillAttendanceHistory();
    await loadRecentAttendance();

    _registerNotificationHandler();
    await _schedulePendingEndNotifications();

    _isLoading = false;
    notifyListeners();
  }

  // ==================== TRAININGS ====================

  Future<void> loadTrainings() async {
    _trainings = await _db.getAllTrainings();
    notifyListeners();
  }

  Future<void> addTraining(Training training) async {
    final id = await _db.insertTraining(training);
    _trainings.add(training.copyWith(id: id));

    // Generiere Anwesenheitseinträge für die nächsten Wochen
    await _generateAttendanceEntries(training.copyWith(id: id));
    await loadRecentAttendance();

    notifyListeners();
  }

  Future<void> updateTraining(Training training) async {
    await _db.updateTraining(training);
    final index = _trainings.indexWhere((t) => t.id == training.id);
    if (index != -1) {
      _trainings[index] = training;
    }
    notifyListeners();
  }

  Future<void> updateTrainingEffective({
    required Training training,
    required DateTime effectiveDate,
  }) async {
    final index = _trainings.indexWhere((t) => t.id == training.id);
    final previous = index != -1 ? _trainings[index] : await _db.getTrainingById(training.id!);
    if (previous == null) return;

    final effective = DateTime(
      effectiveDate.year,
      effectiveDate.month,
      effectiveDate.day,
    );

    await _db.updateTraining(training);
    if (index != -1) {
      _trainings[index] = training;
    }

    await _db.updateAttendanceSnapshotsForTraining(
      trainingId: training.id!,
      toDate: effective,
      name: previous.name,
      startTime: previous.startTime,
      endTime: previous.endTime,
    );
    await _db.updateAttendanceSnapshotsForTraining(
      trainingId: training.id!,
      fromDate: effective,
      name: training.name,
      startTime: training.startTime,
      endTime: training.endTime,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final regenStart = effective.isAfter(today)
        ? effective
        : today.add(const Duration(days: 1));
    await _removeFutureAttendanceAndNotifications(training.id!, regenStart);
    await _generateAttendanceEntriesFromDate(training, regenStart);

    await loadRecentAttendance();
    notifyListeners();
  }

  Future<void> deleteTraining(int id) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    await _removeFutureAttendanceAndNotifications(
      id,
      today.add(const Duration(days: 1)),
    );
    await _db.deleteTraining(id);
    _trainings.removeWhere((t) => t.id == id);
    await loadRecentAttendance();
    notifyListeners();
  }

  Future<DeletedTrainingData> deleteTrainingWithUndo(Training training) async {
    final attendanceEntries = await _db.getAttendanceForTraining(training.id!);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final futureEntries =
        attendanceEntries.where((a) => a.date.isAfter(today)).toList();
    await deleteTraining(training.id!);
    return DeletedTrainingData(training, futureEntries);
  }

  Future<void> restoreTraining(DeletedTrainingData data) async {
    await _db.insertTrainingWithId(
      data.training.copyWith(isActive: true),
    );
    for (final attendance in data.attendanceEntries) {
      await _db.insertAttendanceWithId(attendance);
      final training = data.training;
      if (attendance.id != null && attendance.date.isAfter(DateTime.now())) {
        await _scheduleTrainingEndNotification(attendance, training);
      }
    }
    await loadTrainings();
    await loadRecentAttendance();
    await _schedulePendingEndNotifications();
    notifyListeners();
  }

  // ==================== EVENTS ====================

  Future<void> loadEvents() async {
    _events = await _db.getAllEvents();
    notifyListeners();
  }

  Future<void> addEvent(Event event) async {
    final id = await _db.insertEvent(event);
    final newEvent = event.copyWith(id: id);
    _events.add(newEvent);

    // Generiere Anwesenheitseintrag für das Event
    final attendance = Attendance(
      eventId: id,
      date: event.date,
      status: AttendanceStatus.pending,
      nameSnapshot: event.name,
      startTimeSnapshot: event.startTime,
      endTimeSnapshot: event.endTime,
    );
    final attendanceId = await _db.insertAttendance(attendance);
    await _scheduleEventEndNotification(
      attendance.copyWith(id: attendanceId),
      newEvent,
    );
    await loadRecentAttendance();

    notifyListeners();
  }

  Future<void> updateEvent(Event event) async {
    await _db.updateEvent(event);
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index != -1) {
      _events[index] = event;
    }
    notifyListeners();
  }

  Future<void> deleteEvent(int id) async {
    final attendanceEntries = await _db.getAttendanceForEvent(id);
    for (final attendance in attendanceEntries) {
      if (attendance.id != null) {
        await NotificationService().cancelAttendanceNotification(
          attendance.id!,
        );
      }
    }
    await _db.deleteEvent(id);
    _events.removeWhere((e) => e.id == id);
    await loadRecentAttendance();
    notifyListeners();
  }

  Future<DeletedEventData> deleteEventWithUndo(Event event) async {
    final attendanceEntries = await _db.getAttendanceForEvent(event.id!);
    await deleteEvent(event.id!);
    return DeletedEventData(event, attendanceEntries);
  }

  Future<void> restoreEvent(DeletedEventData data) async {
    await _db.insertEventWithId(data.event);
    for (final attendance in data.attendanceEntries) {
      await _db.insertAttendanceWithId(attendance);
    }
    await loadEvents();
    await loadRecentAttendance();
    await _schedulePendingEndNotifications();
    notifyListeners();
  }

  // ==================== ATTENDANCE ====================

  Future<void> loadRecentAttendance() async {
    _recentAttendance = await _db.getRecentAttendance(days: 60);
    notifyListeners();
  }

  Future<List<Attendance>> getAttendanceForTraining(int trainingId) async {
    return await _db.getAttendanceForTraining(trainingId);
  }

  Future<List<Attendance>> getAttendanceForEvent(int eventId) async {
    return await _db.getAttendanceForEvent(eventId);
  }

  Attendance? getLatestOccurrenceForTraining(int trainingId) {
    final entries = _recentAttendance
        .where((a) => a.trainingId == trainingId)
        .toList();
    if (entries.isEmpty) return null;
    return entries.first;
  }

  Attendance? getLatestOccurrenceForTrainingUpToToday(int trainingId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entries = _recentAttendance
        .where((a) => a.trainingId == trainingId)
        .where(
          (a) => !a.date.isAfter(today),
        )
        .toList();
    if (entries.isEmpty) return null;
    return entries.first;
  }

  Attendance? getLatestOccurrenceForEvent(int eventId) {
    final entries =
        _recentAttendance.where((a) => a.eventId == eventId).toList();
    if (entries.isEmpty) return null;
    return entries.first;
  }

  Future<Attendance> ensureAttendanceForTrainingDate({
    required int trainingId,
    required DateTime date,
  }) async {
    final existing = await _db.getAttendanceByDate(
      trainingId: trainingId,
      date: date,
    );
    if (existing != null) return existing;
    Training? training;
    for (final t in _trainings) {
      if (t.id == trainingId) {
        training = t;
        break;
      }
    }
    training ??= await _db.getTrainingById(trainingId);
    final attendance = Attendance(
      trainingId: trainingId,
      date: date,
      status: AttendanceStatus.pending,
      nameSnapshot: training?.name,
      startTimeSnapshot: training?.startTime,
      endTimeSnapshot: training?.endTime,
    );
    final id = await _db.insertAttendance(attendance);
    return attendance.copyWith(id: id);
  }

  Future<Attendance> ensureAttendanceForEvent({
    required int eventId,
    required DateTime date,
  }) async {
    final existing = await _db.getAttendanceByDate(
      eventId: eventId,
      date: date,
    );
    if (existing != null) return existing;
    Event? event;
    for (final e in _events) {
      if (e.id == eventId) {
        event = e;
        break;
      }
    }
    event ??= await _db.getEventById(eventId);
    final attendance = Attendance(
      eventId: eventId,
      date: date,
      status: AttendanceStatus.pending,
      nameSnapshot: event?.name,
      startTimeSnapshot: event?.startTime,
      endTimeSnapshot: event?.endTime,
    );
    final id = await _db.insertAttendance(attendance);
    return attendance.copyWith(id: id);
  }

  Future<void> updateAttendanceStatus(
    Attendance attendance,
    AttendanceStatus status, {
    int lateMinutes = 0,
    int leftEarlyMinutes = 0,
  }) async {
    final previousStatus = attendance.status;
    if (attendance.id != null) {
      await NotificationService().cancelAttendanceNotification(attendance.id!);
    }
    String? nameSnapshot = attendance.nameSnapshot;
    String? startSnapshot = attendance.startTimeSnapshot;
    String? endSnapshot = attendance.endTimeSnapshot;
    if (nameSnapshot == null ||
        startSnapshot == null ||
        endSnapshot == null) {
      if (attendance.trainingId != null) {
        final training =
            await _db.getTrainingById(attendance.trainingId!);
        if (training != null) {
          nameSnapshot = training.name;
          startSnapshot = training.startTime;
          endSnapshot = training.endTime;
        }
      } else if (attendance.eventId != null) {
        final event = await _db.getEventById(attendance.eventId!);
        if (event != null) {
          nameSnapshot = event.name;
          startSnapshot = event.startTime;
          endSnapshot = event.endTime;
        }
      }
    }
    final resolvedLateMinutes =
        status == AttendanceStatus.late ? lateMinutes : 0;
    final resolvedLeftEarlyMinutes =
        status == AttendanceStatus.leftEarly ? leftEarlyMinutes : 0;
    final updated = attendance.copyWith(
      status: status,
      answeredAt: DateTime.now(),
      lateMinutes: resolvedLateMinutes,
      leftEarlyMinutes: resolvedLeftEarlyMinutes,
      nameSnapshot: nameSnapshot,
      startTimeSnapshot: startSnapshot,
      endTimeSnapshot: endSnapshot,
    );
    await _db.updateAttendance(updated);
    await _syncPlankoEntry(updated, previousStatus);
    await loadRecentAttendance();
    notifyListeners();
  }

  Future<void> updateAttendanceStatusById(
    int attendanceId,
    AttendanceStatus status,
  ) async {
    await NotificationService().cancelAttendanceNotification(attendanceId);
    final attendance = await _db.getAttendanceById(attendanceId);
    if (attendance == null) return;
    final previousStatus = attendance.status;
    String? nameSnapshot = attendance.nameSnapshot;
    String? startSnapshot = attendance.startTimeSnapshot;
    String? endSnapshot = attendance.endTimeSnapshot;
    if (nameSnapshot == null ||
        startSnapshot == null ||
        endSnapshot == null) {
      if (attendance.trainingId != null) {
        final training =
            await _db.getTrainingById(attendance.trainingId!);
        if (training != null) {
          nameSnapshot = training.name;
          startSnapshot = training.startTime;
          endSnapshot = training.endTime;
        }
      } else if (attendance.eventId != null) {
        final event = await _db.getEventById(attendance.eventId!);
        if (event != null) {
          nameSnapshot = event.name;
          startSnapshot = event.startTime;
          endSnapshot = event.endTime;
        }
      }
    }
    final updated = attendance.copyWith(
      status: status,
      answeredAt: DateTime.now(),
      lateMinutes: status == AttendanceStatus.late ? attendance.lateMinutes : 0,
      leftEarlyMinutes: status == AttendanceStatus.leftEarly
          ? attendance.leftEarlyMinutes
          : 0,
      nameSnapshot: nameSnapshot,
      startTimeSnapshot: startSnapshot,
      endTimeSnapshot: endSnapshot,
    );
    await _db.updateAttendance(updated);
    await _syncPlankoEntry(updated, previousStatus);
    await loadRecentAttendance();
    notifyListeners();
  }

  /// Holt den letzten Anwesenheitseintrag für ein Training
  Attendance? getLastAttendanceForTraining(int trainingId) {
    final entries = _recentAttendance
        .where((a) => a.trainingId == trainingId && a.isAnswered)
        .toList();
    if (entries.isEmpty) return null;
    return entries.first; // Bereits nach Datum DESC sortiert
  }

  /// Holt den nächsten anstehenden Termin für ein Training
  DateTime? getNextTrainingDate(Training training) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Finde den nächsten Wochentag
    for (int i = 0; i < 7; i++) {
      final checkDate = today.add(Duration(days: i));
      final weekday = checkDate.weekday; // 1=Mo, 7=So

      if (training.weekdays.contains(weekday)) {
        // Prüfe ob die Zeit heute schon vorbei ist
        if (i == 0) {
          final timeParts = training.endTime.split(':');
          final endHour = int.parse(timeParts[0]);
          final endMinute = int.parse(timeParts[1]);
          if (now.hour > endHour ||
              (now.hour == endHour && now.minute >= endMinute)) {
            continue; // Training heute schon vorbei
          }
        }
        return checkDate;
      }
    }
    return null;
  }

  Future<void> _removeFutureAttendanceAndNotifications(
    int trainingId,
    DateTime fromDate,
  ) async {
    final entries = await _db.getAttendanceForTraining(trainingId);
    for (final attendance in entries) {
      if (attendance.date.isBefore(fromDate)) continue;
      if (attendance.id != null) {
        await NotificationService().cancelAttendanceNotification(
          attendance.id!,
        );
      }
    }
    await _db.deleteAttendanceForTrainingFromDate(trainingId, fromDate);
  }

  // Generiert Anwesenheitseinträge für ein Training (nächste 8 Wochen)
  Future<void> _generateAttendanceEntries(Training training) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await _backfillTrainingAttendance(training, today);

    for (int week = 0; week < 8; week++) {
      for (final weekday in training.weekdays) {
        // Berechne das Datum
        final daysUntil = (weekday - today.weekday + 7) % 7 + (week * 7);
        final date = today.add(Duration(days: daysUntil));

        // Nur zukünftige Termine
        if (date.isAfter(today) || date.isAtSameMomentAs(today)) {
          // Prüfe ob schon ein Eintrag existiert
          final existing = await _db.getAttendanceByDate(
            trainingId: training.id,
            date: date,
          );

          if (existing == null) {
            final attendance = Attendance(
              trainingId: training.id,
              date: date,
              status: AttendanceStatus.pending,
              nameSnapshot: training.name,
              startTimeSnapshot: training.startTime,
              endTimeSnapshot: training.endTime,
            );
            final id = await _db.insertAttendance(attendance);
            await _scheduleTrainingEndNotification(
              attendance.copyWith(id: id),
              training,
            );
          }
        }
      }
    }
  }

  Future<void> _generateAttendanceEntriesFromDate(
    Training training,
    DateTime startDate,
  ) async {
    final base = DateTime(startDate.year, startDate.month, startDate.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (int week = 0; week < 8; week++) {
      for (final weekday in training.weekdays) {
        final daysUntil = (weekday - base.weekday + 7) % 7 + (week * 7);
        final date = base.add(Duration(days: daysUntil));
        if (date.isBefore(base)) continue;

        final existing = await _db.getAttendanceByDate(
          trainingId: training.id,
          date: date,
        );

        if (existing == null) {
          final attendance = Attendance(
            trainingId: training.id,
            date: date,
            status: AttendanceStatus.pending,
            nameSnapshot: training.name,
            startTimeSnapshot: training.startTime,
            endTimeSnapshot: training.endTime,
          );
          final id = await _db.insertAttendance(attendance);
          if (!date.isBefore(today)) {
            await _scheduleTrainingEndNotification(
              attendance.copyWith(id: id),
              training,
            );
          }
        }
      }
    }
  }

  Future<void> _backfillAttendanceHistory() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final training in _trainings) {
      await _backfillTrainingAttendance(training, today);
    }
  }

  Future<void> _backfillTrainingAttendance(
    Training training,
    DateTime today,
  ) async {
    int backfillCount = 0;
    var cursor = today.subtract(const Duration(days: 1));
    while (backfillCount < 5) {
      if (training.weekdays.contains(cursor.weekday)) {
        final existing = await _db.getAttendanceByDate(
          trainingId: training.id,
          date: cursor,
        );
        if (existing == null) {
          await _db.insertAttendance(
            Attendance(
              trainingId: training.id,
              date: cursor,
              status: AttendanceStatus.pending,
              nameSnapshot: training.name,
              startTimeSnapshot: training.startTime,
              endTimeSnapshot: training.endTime,
            ),
          );
        }
        backfillCount++;
      }
      cursor = cursor.subtract(const Duration(days: 1));
    }
  }

  Future<void> _scheduleTrainingEndNotification(
    Attendance attendance,
    Training training,
  ) async {
    if (!_settings.notificationsEnabled) return;
    final strings = AppStrings.forLanguage(_settings.language);
    await NotificationService().scheduleTrainingEndNotification(
      attendance: attendance,
      training: training,
      body: strings.trainingEndedNotificationBody,
      actionYesLabel: strings.wasThere,
      actionNoLabel: strings.wasNotThere,
    );
  }

  Future<void> _scheduleEventEndNotification(
    Attendance attendance,
    Event event,
  ) async {
    if (!_settings.notificationsEnabled) return;
    final strings = AppStrings.forLanguage(_settings.language);
    await NotificationService().scheduleEventEndNotification(
      attendance: attendance,
      event: event,
      body: strings.trainingEndedNotificationBody,
      actionYesLabel: strings.wasThere,
      actionNoLabel: strings.wasNotThere,
    );
  }

  void _registerNotificationHandler() {
    NotificationService.onAttendanceAction = (attendanceId, wasPresent) async {
      await updateAttendanceStatusById(
        attendanceId,
        wasPresent ? AttendanceStatus.present : AttendanceStatus.absent,
      );
      final strings = AppStrings.forLanguage(_settings.language);
      await NotificationService().showSavedNotification(
        title: strings.answerSavedTitle,
        body: strings.answerSavedBody,
      );
    };
  }

  Future<void> _schedulePendingEndNotifications() async {
    if (!_settings.notificationsEnabled) return;
    final now = DateTime.now();
    for (final training in _trainings) {
      final attendanceEntries = await _db.getAttendanceForTraining(
        training.id!,
      );
      for (final attendance in attendanceEntries) {
        if (attendance.id == null) continue;
        if (attendance.isAnswered) continue;
        if (attendance.date.isBefore(DateTime(now.year, now.month, now.day))) {
          continue;
        }
        await _scheduleTrainingEndNotification(attendance, training);
      }
    }
    for (final event in _events) {
      final attendanceEntries = await _db.getAttendanceForEvent(event.id!);
      for (final attendance in attendanceEntries) {
        if (attendance.id == null) continue;
        if (attendance.isAnswered) continue;
        if (attendance.date.isBefore(DateTime(now.year, now.month, now.day))) {
          continue;
        }
        await _scheduleEventEndNotification(attendance, event);
      }
    }
  }

  // ==================== SETTINGS ====================

  Future<void> loadSettings() async {
    _settings = await _db.getAppSettings();
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings settings) async {
    final previousTemplate = _settings.customTemplatePath;
    await _db.saveAppSettings(settings);
    _settings = settings;
    notifyListeners();

    if (!_settings.notificationsEnabled) {
      await NotificationService().cancelAllNotifications();
    } else {
      await _schedulePendingEndNotifications();
    }

    if (previousTemplate != _settings.customTemplatePath) {
      await PlankoService().rebuildCurrentPlanko(
        customTemplatePath: _settings.customTemplatePath,
      );
    }
  }

  Future<void> _syncPlankoEntry(
    Attendance updated,
    AttendanceStatus previousStatus,
  ) async {
    if (updated.id == null) return;
    final plankoService = PlankoService();

    if (updated.isPresentLike) {
      if (updated.nameSnapshot != null &&
          updated.startTimeSnapshot != null &&
          updated.endTimeSnapshot != null) {
        await plankoService.writeAttendanceEntry(
          attendanceId: updated.id!,
          name: updated.nameSnapshot!,
          date: updated.date,
          startTime: updated.startTimeSnapshot!,
          endTime: updated.endTimeSnapshot!,
          timeNote: updated.timeNote(),
          customTemplatePath: _settings.customTemplatePath,
        );
        return;
      }
      Training? training;
      Event? event;
      if (updated.trainingId != null) {
        for (final t in _trainings) {
          if (t.id == updated.trainingId) {
            training = t;
            break;
          }
        }
        training ??= await _db.getTrainingById(updated.trainingId!);
      } else if (updated.eventId != null) {
        for (final e in _events) {
          if (e.id == updated.eventId) {
            event = e;
            break;
          }
        }
        event ??= await _db.getEventById(updated.eventId!);
      }
      if (training != null) {
        await plankoService.writeAttendanceEntry(
          attendanceId: updated.id!,
          name: training.name,
          date: updated.date,
          startTime: training.startTime,
          endTime: training.endTime,
          timeNote: updated.timeNote(),
          customTemplatePath: _settings.customTemplatePath,
        );
      } else if (event != null) {
        await plankoService.writeAttendanceEntry(
          attendanceId: updated.id!,
          name: event.name,
          date: updated.date,
          startTime: event.startTime,
          endTime: event.endTime,
          timeNote: updated.timeNote(),
          customTemplatePath: _settings.customTemplatePath,
        );
      }
    } else if (previousStatus == AttendanceStatus.present ||
        previousStatus == AttendanceStatus.late ||
        previousStatus == AttendanceStatus.leftEarly) {
      await plankoService.removeAttendanceEntry(
        attendanceId: updated.id!,
        customTemplatePath: _settings.customTemplatePath,
      );
    }
  }

  // ==================== RESET ====================

  Future<void> resetAllData() async {
    await _db.resetAllData();
    _trainings = [];
    _events = [];
    _recentAttendance = [];
    notifyListeners();
  }
}

class DeletedTrainingData {
  final Training training;
  final List<Attendance> attendanceEntries;
  DeletedTrainingData(this.training, this.attendanceEntries);
}

class DeletedEventData {
  final Event event;
  final List<Attendance> attendanceEntries;
  DeletedEventData(this.event, this.attendanceEntries);
}
