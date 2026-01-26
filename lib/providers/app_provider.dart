import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';

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

  Future<void> deleteTraining(int id) async {
    await _db.deleteTraining(id);
    _trainings.removeWhere((t) => t.id == id);
    await loadRecentAttendance();
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
    await _db.insertAttendance(
      Attendance(
        eventId: id,
        date: event.date,
        status: AttendanceStatus.pending,
      ),
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
    await _db.deleteEvent(id);
    _events.removeWhere((e) => e.id == id);
    await loadRecentAttendance();
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

  Future<void> updateAttendanceStatus(
    Attendance attendance,
    AttendanceStatus status,
  ) async {
    final updated = attendance.copyWith(
      status: status,
      answeredAt: DateTime.now(),
    );
    await _db.updateAttendance(updated);
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

  // Generiert Anwesenheitseinträge für ein Training (nächste 8 Wochen)
  Future<void> _generateAttendanceEntries(Training training) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

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
            await _db.insertAttendance(
              Attendance(
                trainingId: training.id,
                date: date,
                status: AttendanceStatus.pending,
              ),
            );
          }
        }
      }
    }
  }

  // ==================== SETTINGS ====================

  Future<void> loadSettings() async {
    _settings = await _db.getAppSettings();
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings settings) async {
    await _db.saveAppSettings(settings);
    _settings = settings;
    notifyListeners();
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
