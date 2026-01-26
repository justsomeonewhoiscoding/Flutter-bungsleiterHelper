/// App-Einstellungen
class AppSettings {
  final String language; // 'de', 'en'
  final String? customTemplatePath; // Pfad zum DOCX-Template
  final int notificationMinutesBefore; // Minuten vor Training
  final bool notificationsEnabled;

  AppSettings({
    this.language = 'de',
    this.customTemplatePath,
    this.notificationMinutesBefore = 30,
    this.notificationsEnabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'language': language,
      'customTemplatePath': customTemplatePath,
      'notificationMinutesBefore': notificationMinutesBefore,
      'notificationsEnabled': notificationsEnabled ? 1 : 0,
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      language: map['language'] as String? ?? 'de',
      customTemplatePath: map['customTemplatePath'] as String?,
      notificationMinutesBefore: map['notificationMinutesBefore'] as int? ?? 30,
      notificationsEnabled: (map['notificationsEnabled'] as int?) == 1,
    );
  }

  AppSettings copyWith({
    String? language,
    String? customTemplatePath,
    int? notificationMinutesBefore,
    bool? notificationsEnabled,
  }) {
    return AppSettings(
      language: language ?? this.language,
      customTemplatePath: customTemplatePath ?? this.customTemplatePath,
      notificationMinutesBefore:
          notificationMinutesBefore ?? this.notificationMinutesBefore,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
