import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/models.dart';
import 'database_service.dart';
import 'planko_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // Action IDs für Quick Actions
  static const String actionYes = 'ACTION_YES';
  static const String actionNo = 'ACTION_NO';

  // Callback für Notification Actions
  static Function(int attendanceId, bool wasPresent)? onAttendanceAction;

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationResponse,
    );

    // Android Notification Channel erstellen
    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }
  }

  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'training_reminders',
      'Training Erinnerungen',
      description: 'Erinnerungen vor anstehenden Trainings',
      importance: Importance.high,
      playSound: true,
    );
    const savedChannel = AndroidNotificationChannel(
      'training_saved',
      'Training gespeichert',
      description: 'Bestätigung nach dem Speichern',
      importance: Importance.low,
      playSound: false,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(savedChannel);
  }

  static void _onNotificationResponse(NotificationResponse response) {
    _handleNotificationAction(response);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    _handleNotificationAction(response);
  }

  static void _handleNotificationAction(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    final attendanceId = int.tryParse(payload);
    if (attendanceId == null) return;

    final wasPresent = response.actionId == actionYes;
    final wasAbsent = response.actionId == actionNo;
    if (!wasPresent && !wasAbsent) return;

    if (onAttendanceAction != null) {
      onAttendanceAction?.call(attendanceId, wasPresent);
    } else {
      unawaited(_updateAttendanceInBackground(attendanceId, wasPresent));
    }
  }

  static Future<void> _updateAttendanceInBackground(
    int attendanceId,
    bool wasPresent,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();
    final db = DatabaseService();
    final attendance = await db.getAttendanceById(attendanceId);
    if (attendance == null) return;
    final previousStatus = attendance.status;
    final updated = attendance.copyWith(
      status: wasPresent ? AttendanceStatus.present : AttendanceStatus.absent,
      answeredAt: DateTime.now(),
      lateMinutes: wasPresent ? attendance.lateMinutes : 0,
    );
    await db.updateAttendance(updated);
    await _updatePlankoForAttendance(updated, previousStatus, db);
    await NotificationService().showSavedNotification();
  }

  static Future<void> _updatePlankoForAttendance(
    Attendance updated,
    AttendanceStatus previousStatus,
    DatabaseService db,
  ) async {
    if (updated.id == null) return;
    final plankoService = PlankoService();
    if (updated.status == AttendanceStatus.present) {
      if (updated.trainingId != null) {
        final training = await db.getTrainingById(updated.trainingId!);
        if (training == null) return;
        await plankoService.writeAttendanceEntry(
          attendanceId: updated.id!,
          name: training.name,
          date: updated.date,
          startTime: training.startTime,
          endTime: training.endTime,
        );
      } else if (updated.eventId != null) {
        final event = await db.getEventById(updated.eventId!);
        if (event == null) return;
        await plankoService.writeAttendanceEntry(
          attendanceId: updated.id!,
          name: event.name,
          date: updated.date,
          startTime: event.startTime,
          endTime: event.endTime,
        );
      }
    } else if (previousStatus == AttendanceStatus.present) {
      await plankoService.removeAttendanceEntry(
        attendanceId: updated.id!,
      );
    }
  }

  /// Berechtigung für Benachrichtigungen anfordern
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    } else if (Platform.isIOS) {
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return false;
  }

  /// Plant eine Benachrichtigung für ein Training
  Future<void> scheduleTrainingReminder({
    required int notificationId,
    required Training training,
    required DateTime trainingDate,
    required int minutesBefore,
    int? attendanceId,
  }) async {
    final scheduledTime = trainingDate.subtract(
      Duration(minutes: minutesBefore),
    );

    // Nicht in der Vergangenheit planen
    if (scheduledTime.isBefore(DateTime.now())) return;

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'training_reminders',
        'Training Erinnerungen',
        channelDescription: 'Erinnerungen vor anstehenden Trainings',
        importance: Importance.high,
        priority: Priority.high,
        actions: [
          const AndroidNotificationAction(
            actionYes,
            '✓ Ja, bin da',
            showsUserInterface: false,
          ),
          const AndroidNotificationAction(
            actionNo,
            '✗ Nein',
            showsUserInterface: false,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.zonedSchedule(
      notificationId,
      training.name,
      'Training um ${training.startTime} Uhr - Bist du dabei?',
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: attendanceId?.toString(),
      matchDateTimeComponents: null,
    );
  }

  /// Plant wöchentlich wiederkehrende Benachrichtigungen für ein Training
  Future<void> scheduleWeeklyTrainingReminders({
    required Training training,
    required int minutesBefore,
  }) async {
    // Für jeden Wochentag des Trainings eine Benachrichtigung planen
    for (final weekday in training.weekdays) {
      final timeParts = training.startTime.split(':');
      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // Berechne nächsten Termin
      var nextDate = _getNextWeekday(weekday);
      nextDate = DateTime(
        nextDate.year,
        nextDate.month,
        nextDate.day,
        hour,
        minute,
      );

      final scheduledTime = nextDate.subtract(Duration(minutes: minutesBefore));

      if (scheduledTime.isAfter(DateTime.now())) {
        final notificationId = training.id! * 10 + weekday;

        final notificationDetails = NotificationDetails(
          android: AndroidNotificationDetails(
            'training_reminders',
            'Training Erinnerungen',
            channelDescription: 'Erinnerungen vor anstehenden Trainings',
            importance: Importance.high,
            priority: Priority.high,
            actions: [
              const AndroidNotificationAction(
                actionYes,
                '✓ Ja, bin da',
                showsUserInterface: false,
              ),
              const AndroidNotificationAction(
                actionNo,
                '✗ Nein',
                showsUserInterface: false,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        );

        // Wöchentlich wiederholen
        await _notifications.zonedSchedule(
          notificationId,
          training.name,
          'Training um ${training.startTime} Uhr - Bist du dabei?',
          tz.TZDateTime.from(scheduledTime, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  DateTime _getNextWeekday(int weekday) {
    final now = DateTime.now();
    var daysUntil = weekday - now.weekday;
    if (daysUntil <= 0) daysUntil += 7;
    return now.add(Duration(days: daysUntil));
  }

  /// Entfernt alle Benachrichtigungen für ein Training
  Future<void> cancelTrainingReminders(int trainingId) async {
    for (int weekday = 1; weekday <= 7; weekday++) {
      await _notifications.cancel(trainingId * 10 + weekday);
    }
  }

  /// Entfernt alle Benachrichtigungen
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Zeigt eine sofortige Test-Benachrichtigung
  Future<void> showTestNotification() async {
    debugPrint('NotificationService: showTestNotification called');

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'training_reminders',
        'Training Erinnerungen',
        channelDescription: 'Erinnerungen vor anstehenden Trainings',
        importance: Importance.high,
        priority: Priority.high,
        actions: [
          AndroidNotificationAction(
            actionYes,
            '✓ Ja, bin da',
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            actionNo,
            '✗ Nein',
            showsUserInterface: false,
          ),
        ],
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _notifications.show(
        0,
        'Test Training',
        'Training um 18:00 Uhr - Bist du dabei?',
        notificationDetails,
      );
      debugPrint('NotificationService: Notification sent successfully');
    } catch (e) {
      debugPrint('NotificationService: Error sending notification: $e');
      rethrow;
    }
  }

  /// Plant eine Benachrichtigung, wenn das Training vorbei ist
  Future<void> scheduleTrainingEndNotification({
    required Attendance attendance,
    required Training training,
    String? body,
    String? actionYesLabel,
    String? actionNoLabel,
  }) async {
    if (attendance.id == null) return;

    final timeParts = training.endTime.split(':');
    final endHour = int.parse(timeParts[0]);
    final endMinute = int.parse(timeParts[1]);

    final scheduledTime = DateTime(
      attendance.date.year,
      attendance.date.month,
      attendance.date.day,
      endHour,
      endMinute,
    );

    if (scheduledTime.isBefore(DateTime.now())) return;

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'training_reminders',
        'Training Erinnerungen',
        channelDescription: 'Erinnerungen vor anstehenden Trainings',
        importance: Importance.high,
        priority: Priority.high,
        actions: [
          AndroidNotificationAction(
            actionYes,
            actionYesLabel ?? 'Ja, war da',
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            actionNo,
            actionNoLabel ?? 'Nein',
            showsUserInterface: false,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.zonedSchedule(
      attendance.id!,
      training.name,
      body ?? 'Training ist vorbei - warst du dabei?',
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: attendance.id!.toString(),
      matchDateTimeComponents: null,
    );
  }

  Future<void> scheduleEventEndNotification({
    required Attendance attendance,
    required Event event,
    String? body,
    String? actionYesLabel,
    String? actionNoLabel,
  }) async {
    if (attendance.id == null) return;

    final timeParts = event.endTime.split(':');
    final endHour = int.parse(timeParts[0]);
    final endMinute = int.parse(timeParts[1]);

    final scheduledTime = DateTime(
      attendance.date.year,
      attendance.date.month,
      attendance.date.day,
      endHour,
      endMinute,
    );

    if (scheduledTime.isBefore(DateTime.now())) return;

    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'training_reminders',
        'Training Erinnerungen',
        channelDescription: 'Erinnerungen vor anstehenden Trainings',
        importance: Importance.high,
        priority: Priority.high,
        actions: [
          AndroidNotificationAction(
            actionYes,
            actionYesLabel ?? 'Ja, war da',
            showsUserInterface: false,
          ),
          AndroidNotificationAction(
            actionNo,
            actionNoLabel ?? 'Nein',
            showsUserInterface: false,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notifications.zonedSchedule(
      attendance.id!,
      event.name,
      body ?? 'Training ist vorbei - warst du dabei?',
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: attendance.id!.toString(),
      matchDateTimeComponents: null,
    );
  }

  Future<void> cancelAttendanceNotification(int attendanceId) async {
    await _notifications.cancel(attendanceId);
  }

  Future<void> showSavedNotification() async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'training_saved',
        'Training gespeichert',
        channelDescription: 'Bestätigung nach dem Speichern',
        importance: Importance.low,
        priority: Priority.low,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      ),
    );
    await _notifications.show(
      1,
      'Gespeichert',
      'Antwort wurde gespeichert',
      notificationDetails,
    );
  }
}
