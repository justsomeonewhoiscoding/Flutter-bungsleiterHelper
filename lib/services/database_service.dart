import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'uebungsleiter_helper.db');

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // Trainings Tabelle
    await db.execute('''
      CREATE TABLE trainings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        weekdays TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // Events Tabelle
    await db.execute('''
      CREATE TABLE events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        date TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // Anwesenheit Tabelle
    await db.execute('''
      CREATE TABLE attendance (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trainingId INTEGER,
        eventId INTEGER,
        date TEXT NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        answeredAt TEXT,
        FOREIGN KEY (trainingId) REFERENCES trainings (id) ON DELETE CASCADE,
        FOREIGN KEY (eventId) REFERENCES events (id) ON DELETE CASCADE
      )
    ''');

    // Einstellungen Tabelle
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  // ==================== TRAININGS ====================

  Future<int> insertTraining(Training training) async {
    final db = await database;
    return await db.insert('trainings', training.toMap());
  }

  Future<List<Training>> getAllTrainings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('trainings');
    return maps.map((map) => Training.fromMap(map)).toList();
  }

  Future<Training?> getTrainingById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trainings',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Training.fromMap(maps.first);
  }

  Future<int> updateTraining(Training training) async {
    final db = await database;
    return await db.update(
      'trainings',
      training.toMap(),
      where: 'id = ?',
      whereArgs: [training.id],
    );
  }

  Future<int> deleteTraining(int id) async {
    final db = await database;
    // Lösche auch zugehörige Anwesenheitseinträge
    await db.delete('attendance', where: 'trainingId = ?', whereArgs: [id]);
    return await db.delete('trainings', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== EVENTS ====================

  Future<int> insertEvent(Event event) async {
    final db = await database;
    return await db.insert('events', event.toMap());
  }

  Future<List<Event>> getAllEvents() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('events');
    return maps.map((map) => Event.fromMap(map)).toList();
  }

  Future<Event?> getEventById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Event.fromMap(maps.first);
  }

  Future<int> updateEvent(Event event) async {
    final db = await database;
    return await db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<int> deleteEvent(int id) async {
    final db = await database;
    await db.delete('attendance', where: 'eventId = ?', whereArgs: [id]);
    return await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== ATTENDANCE ====================

  Future<int> insertAttendance(Attendance attendance) async {
    final db = await database;
    return await db.insert('attendance', attendance.toMap());
  }

  Future<List<Attendance>> getAllAttendance() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      orderBy: 'date DESC',
    );
    return maps.map((map) => Attendance.fromMap(map)).toList();
  }

  Future<List<Attendance>> getAttendanceForTraining(int trainingId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'trainingId = ?',
      whereArgs: [trainingId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Attendance.fromMap(map)).toList();
  }

  Future<List<Attendance>> getAttendanceForEvent(int eventId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'eventId = ?',
      whereArgs: [eventId],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Attendance.fromMap(map)).toList();
  }

  Future<List<Attendance>> getRecentAttendance({int days = 60}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: 'date >= ?',
      whereArgs: [cutoffDate.toIso8601String()],
      orderBy: 'date DESC',
    );
    return maps.map((map) => Attendance.fromMap(map)).toList();
  }

  Future<Attendance?> getAttendanceByDate({
    int? trainingId,
    int? eventId,
    required DateTime date,
  }) async {
    final db = await database;
    final dateStr = DateTime(date.year, date.month, date.day).toIso8601String();

    String where;
    List<dynamic> whereArgs;

    if (trainingId != null) {
      where = 'trainingId = ? AND date LIKE ?';
      whereArgs = [trainingId, '$dateStr%'];
    } else {
      where = 'eventId = ? AND date LIKE ?';
      whereArgs = [eventId, '$dateStr%'];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'attendance',
      where: where,
      whereArgs: whereArgs,
    );
    if (maps.isEmpty) return null;
    return Attendance.fromMap(maps.first);
  }

  Future<int> updateAttendance(Attendance attendance) async {
    final db = await database;
    return await db.update(
      'attendance',
      attendance.toMap(),
      where: 'id = ?',
      whereArgs: [attendance.id],
    );
  }

  Future<int> deleteAttendance(int id) async {
    final db = await database;
    return await db.delete('attendance', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== SETTINGS ====================

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String?;
  }

  Future<AppSettings> getAppSettings() async {
    final language = await getSetting('language') ?? 'de';
    final customTemplatePath = await getSetting('customTemplatePath');
    final notificationMinutes =
        int.tryParse(await getSetting('notificationMinutesBefore') ?? '30') ??
        30;
    final notificationsEnabled =
        (await getSetting('notificationsEnabled') ?? '1') == '1';

    return AppSettings(
      language: language,
      customTemplatePath: customTemplatePath,
      notificationMinutesBefore: notificationMinutes,
      notificationsEnabled: notificationsEnabled,
    );
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    await setSetting('language', settings.language);
    if (settings.customTemplatePath != null) {
      await setSetting('customTemplatePath', settings.customTemplatePath!);
    }
    await setSetting(
      'notificationMinutesBefore',
      settings.notificationMinutesBefore.toString(),
    );
    await setSetting(
      'notificationsEnabled',
      settings.notificationsEnabled ? '1' : '0',
    );
  }

  // ==================== RESET ====================

  Future<void> resetAllData() async {
    final db = await database;
    await db.delete('attendance');
    await db.delete('trainings');
    await db.delete('events');
    // Settings bleiben erhalten
  }
}
