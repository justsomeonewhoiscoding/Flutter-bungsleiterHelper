import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class AppStrings {
  final String language;
  const AppStrings._(this.language);

  static AppStrings of(BuildContext context) {
    final lang = context.watch<AppProvider>().settings.language;
    return AppStrings._(_resolveLanguage(lang));
  }

  static AppStrings forLanguage(String language) =>
      AppStrings._(_resolveLanguage(language));

  static String _resolveLanguage(String language) {
    if (language == 'system') {
      final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      return code.toLowerCase().startsWith('de') ? 'de' : 'en';
    }
    return language;
  }

  String _t(String key) =>
      _values[language]?[key] ?? _values['de']![key]!;

  // Generic
  String get appTitle => _t('appTitle');
  String get training => _t('training');
  String get event => _t('event');
  String get save => _t('save');
  String get cancel => _t('cancel');
  String get delete => _t('delete');
  String get undo => _t('undo');
  String get deleted => _t('deleted');
  String get yes => _t('yes');
  String get no => _t('no');
  String get timeSuffix => _t('timeSuffix');

  // Home
  String get yourTrainings => _t('yourTrainings');
  String get noTrainingsTitle => _t('noTrainingsTitle');
  String get noTrainingsSubtitle => _t('noTrainingsSubtitle');
  String lastLabel(String status) =>
      _t('lastLabel').replaceAll('{status}', status);
  String nextLabel(String date) => _t('nextLabel').replaceAll('{date}', date);
  String deleteTrainingTitle(String name) =>
      _t('deleteTrainingTitle').replaceAll('{name}', name);
  String deleteTrainingBody(String name) =>
      _t('deleteTrainingBody').replaceAll('{name}', name);

  // Add Training
  String get addTrainingTitle => _t('addTrainingTitle');
  String get trainingNameHint => _t('trainingNameHint');
  String get weekdaysLabel => _t('weekdaysLabel');
  String get startTimeLabel => _t('startTimeLabel');
  String get endTimeLabel => _t('endTimeLabel');
  List<String> get weekdayShort =>
      _weekdayShort[language] ?? _weekdayShort['de']!;
  String formatWeekdays(List<int> weekdays) =>
      weekdays.map((d) => weekdayShort[d - 1]).join(' ');

  // Add Event
  String get addEventTitle => _t('addEventTitle');
  String get addEventInfo => _t('addEventInfo');
  String get eventNameHint => _t('eventNameHint');
  String get dateLabel => _t('dateLabel');

  // Attendance dialog/history
  String get attendanceQuestion => _t('attendanceQuestion');
  String get wasThere => _t('wasThere');
  String get wasNotThere => _t('wasNotThere');
  String get attendanceHistoryShort => _t('attendanceHistoryShort');
  String get noEntries => _t('noEntries');
  String lateLabel(int minutes) =>
      _t('lateLabel').replaceAll('{minutes}', minutes.toString());
  String get latenessTitle => _t('latenessTitle');
  String get onTime => _t('onTime');
  String get apply => _t('apply');

  // Settings
  String get settingsTitle => _t('settingsTitle');
  String get featuresOverview => _t('featuresOverview');
  String get documentSection => _t('documentSection');
  String get selectTemplate => _t('selectTemplate');
  String get customTemplateSelected => _t('customTemplateSelected');
  String get defaultTemplateUsed => _t('defaultTemplateUsed');
  String get archiveSection => _t('archiveSection');
  String get openPlanko => _t('openPlanko');
  String get sharePlanko => _t('sharePlanko');
  String get shareArchive => _t('shareArchive');
  String get manageArchive => _t('manageArchive');
  String get languageSection => _t('languageSection');
  String currentLanguage(String lang) =>
      _t('currentLanguage').replaceAll('{language}', lang);
  String get changeLanguage => _t('changeLanguage');
  String get systemLanguage => _t('systemLanguage');
  String get dangerZone => _t('dangerZone');
  String get dangerZoneSubtitle => _t('dangerZoneSubtitle');
  String get rewritePlanko => _t('rewritePlanko');
  String get templateSaved => _t('templateSaved');
  String get plankoCreating => _t('plankoCreating');
  String plankoCreated(String fileName) =>
      _t('plankoCreated').replaceAll('{fileName}', fileName);
  String get plankoCreateError => _t('plankoCreateError');
  String get archiveCreating => _t('archiveCreating');
  String get testNotification => _t('testNotification');
  String get notificationSent => _t('notificationSent');
  String get notificationPermissionDenied =>
      _t('notificationPermissionDenied');
  String get deleteArchive => _t('deleteArchive');
  String get archiveDeleted => _t('archiveDeleted');
  String get close => _t('close');
  String get chooseLanguage => _t('chooseLanguage');
  String get deleteAllTitle => _t('deleteAllTitle');
  String get deleteAllBody => _t('deleteAllBody');
  String get allDataDeleted => _t('allDataDeleted');

  // Validation & misc
  String get validationMissingFields => _t('validationMissingFields');
  String get validationSelectWeekday => _t('validationSelectWeekday');
  String get validationEndAfterStart => _t('validationEndAfterStart');
  String get eventBadge => _t('eventBadge');
  String get statusOpen => _t('statusOpen');
  String get templateInvalid => _t('templateInvalid');
  String get currentPlankoMissing => _t('currentPlankoMissing');

  // Notification
  String get trainingEndedNotificationBody =>
      _t('trainingEndedNotificationBody');

  static const Map<String, Map<String, String>> _values = {
    'de': {
      'appTitle': 'ÜbungsleiterHelper',
      'training': 'Training',
      'event': 'Event',
      'save': 'Speichern',
      'cancel': 'Abbrechen',
      'delete': 'Löschen',
      'undo': 'Rückgängig',
      'deleted': 'gelöscht',
      'yes': 'JA',
      'no': 'NEIN',
      'timeSuffix': 'Uhr',
      'yourTrainings': 'Deine Trainings',
      'noTrainingsTitle': 'Noch keine Trainings',
      'noTrainingsSubtitle': 'Füge dein erstes Training hinzu!',
      'lastLabel': 'letztes: {status}',
      'nextLabel': 'nächstes: {date}',
      'deleteTrainingTitle': 'Training löschen?',
      'deleteTrainingBody':
          'Möchtest du "{name}" wirklich löschen? Alle Anwesenheitseinträge werden ebenfalls gelöscht.',
      'addTrainingTitle': 'Training hinzufügen',
      'trainingNameHint': 'Name (z.B. Kinderturnen)',
      'weekdaysLabel': 'Wochentage',
      'startTimeLabel': 'Startzeit',
      'endTimeLabel': 'Endzeit',
      'addEventTitle': 'Einmaliges Event',
      'addEventInfo':
          'Erstelle ein einmaliges Event, das nur an einem bestimmten Datum stattfindet (z.B. Weihnachtsfeier, Sondertraining).',
      'eventNameHint': 'Event-Name',
      'dateLabel': 'Datum',
      'attendanceQuestion': 'Warst du bei diesem Training?',
      'wasThere': 'Ja, war da',
      'wasNotThere': 'Nein, war nicht da',
      'attendanceHistoryShort': 'Anwesenheit',
      'noEntries': 'Keine Einträge vorhanden',
      'lateLabel': 'Verspätung: {minutes} min',
      'latenessTitle': 'Verspätung',
      'onTime': 'Pünktlich',
      'apply': 'Übernehmen',
      'settingsTitle': 'Einstellungen',
      'featuresOverview': 'Funktionsübersicht',
      'documentSection': 'Dokument',
      'selectTemplate': 'DOCX-Template auswählen',
      'customTemplateSelected': 'Custom Template ausgewählt',
      'defaultTemplateUsed': 'Standard RTV-DOCX Template wird genutzt',
      'archiveSection': 'Archiv',
      'openPlanko': 'Aktuelles Planko öffnen',
      'sharePlanko': 'Aktuelles Planko teilen / speichern',
      'shareArchive': 'Archiv als ZIP teilen',
      'manageArchive': 'Archiv verwalten',
      'languageSection': 'Sprache',
      'currentLanguage': 'Aktuelle Sprache: {language}',
      'changeLanguage': 'Sprache ändern',
      'systemLanguage': 'System',
      'dangerZone': 'Gefahrenzone',
      'dangerZoneSubtitle': 'Diese Aktion kann nicht rückgängig gemacht werden.',
      'rewritePlanko': 'Planko neu schreiben',
      'templateSaved': 'Template wurde gespeichert',
      'plankoCreating': 'Planko wird erstellt...',
      'plankoCreated': 'Planko erstellt: {fileName}',
      'plankoCreateError': 'Fehler beim Erstellen des Planko',
      'archiveCreating': 'Archiv wird erstellt...',
      'testNotification': 'Test-Benachrichtigung',
      'notificationSent': 'Benachrichtigung gesendet',
      'notificationPermissionDenied':
          'Benachrichtigungsberechtigung wurde nicht erteilt',
      'deleteArchive': 'Archiv löschen',
      'archiveDeleted': 'Archiv gelöscht',
      'close': 'Schließen',
      'chooseLanguage': 'Sprache wählen',
      'deleteAllTitle': 'Alle Daten löschen?',
      'deleteAllBody':
          'Alle Trainings, Events und Anwesenheitseinträge werden unwiderruflich gelöscht. Diese Aktion kann nicht rückgängig gemacht werden!',
      'allDataDeleted': 'Alle Daten wurden gelöscht',
      'validationMissingFields': 'Bitte alle Pflichtfelder ausfüllen.',
      'validationSelectWeekday': 'Bitte mindestens einen Wochentag auswählen.',
      'validationEndAfterStart': 'Endzeit muss nach der Startzeit liegen.',
      'eventBadge': 'Einmalig',
      'statusOpen': 'Offen',
      'templateInvalid': 'Template ist ungültig.',
      'currentPlankoMissing': 'Planko fehlt oder konnte nicht erstellt werden.',
      'trainingEndedNotificationBody':
          'Training ist vorbei - warst du dabei?',
    },
    'en': {
      'appTitle': 'ÜbungsleiterHelper',
      'training': 'Training',
      'event': 'Event',
      'save': 'Save',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'undo': 'Undo',
      'deleted': 'deleted',
      'yes': 'YES',
      'no': 'NO',
      'timeSuffix': 'h',
      'yourTrainings': 'Your trainings',
      'noTrainingsTitle': 'No trainings yet',
      'noTrainingsSubtitle': 'Add your first training!',
      'lastLabel': 'last: {status}',
      'nextLabel': 'next: {date}',
      'deleteTrainingTitle': 'Delete training?',
      'deleteTrainingBody':
          'Do you really want to delete "{name}"? All attendance entries will also be deleted.',
      'addTrainingTitle': 'Add training',
      'trainingNameHint': 'Name (e.g. Kids gymnastics)',
      'weekdaysLabel': 'Weekdays',
      'startTimeLabel': 'Start time',
      'endTimeLabel': 'End time',
      'addEventTitle': 'One-time event',
      'addEventInfo':
          'Create a one-time event that only takes place on a specific date (e.g. holiday party, special session).',
      'eventNameHint': 'Event name',
      'dateLabel': 'Date',
      'attendanceQuestion': 'Did you attend this training?',
      'wasThere': 'Yes, I was there',
      'wasNotThere': 'No, I was not there',
      'attendanceHistoryShort': 'Attendance',
      'noEntries': 'No entries found',
      'lateLabel': 'Late: {minutes} min',
      'latenessTitle': 'Lateness',
      'onTime': 'On time',
      'apply': 'Apply',
      'settingsTitle': 'Settings',
      'featuresOverview': 'Feature overview',
      'documentSection': 'Document',
      'selectTemplate': 'Select DOCX template',
      'customTemplateSelected': 'Custom template selected',
      'defaultTemplateUsed': 'Default RTV DOCX template is used',
      'archiveSection': 'Archive',
      'openPlanko': 'Open current plan',
      'sharePlanko': 'Share / save current plan',
      'shareArchive': 'Share archive as ZIP',
      'manageArchive': 'Manage archive',
      'languageSection': 'Language',
      'currentLanguage': 'Current language: {language}',
      'changeLanguage': 'Change language',
      'systemLanguage': 'System',
      'dangerZone': 'Danger zone',
      'dangerZoneSubtitle': 'This action cannot be undone.',
      'rewritePlanko': 'Rewrite plan',
      'templateSaved': 'Template saved',
      'plankoCreating': 'Creating plan...',
      'plankoCreated': 'Plan created: {fileName}',
      'plankoCreateError': 'Failed to create plan',
      'archiveCreating': 'Creating archive...',
      'testNotification': 'Test notification',
      'notificationSent': 'Notification sent',
      'notificationPermissionDenied':
          'Notification permission was not granted',
      'deleteArchive': 'Delete archive',
      'archiveDeleted': 'Archive deleted',
      'close': 'Close',
      'chooseLanguage': 'Choose language',
      'deleteAllTitle': 'Delete all data?',
      'deleteAllBody':
          'All trainings, events and attendance entries will be permanently deleted. This action cannot be undone!',
      'allDataDeleted': 'All data was deleted',
      'validationMissingFields': 'Please fill out all required fields.',
      'validationSelectWeekday': 'Please select at least one weekday.',
      'validationEndAfterStart': 'End time must be after start time.',
      'eventBadge': 'One-time',
      'statusOpen': 'Open',
      'templateInvalid': 'Template is invalid.',
      'currentPlankoMissing': 'Plan is missing or could not be created.',
      'trainingEndedNotificationBody':
          'Training is over - were you there?',
    },
  };

  static const Map<String, List<String>> _weekdayShort = {
    'de': ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'],
    'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  };
}
