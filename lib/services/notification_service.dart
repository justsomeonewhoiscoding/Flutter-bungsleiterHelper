import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/models.dart';

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

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
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

    if (response.actionId == actionYes) {
      onAttendanceAction?.call(attendanceId, true);
    } else if (response.actionId == actionNo) {
      onAttendanceAction?.call(attendanceId, false);
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

    final timeParts = training.startTime.split(':');
    final startHour = int.parse(timeParts[0]);
    final startMinute = int.parse(timeParts[1]);

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

    await _notifications.show(
      0,
      'Test Training',
      'Training um 18:00 Uhr - Bist du dabei?',
      notificationDetails,
    );
  }
}
