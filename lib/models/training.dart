/// Model für wiederkehrende Trainings
class Training {
  final int? id;
  final String name;
  final List<int> weekdays; // 1=Mo, 2=Di, ..., 7=So
  final String startTime; // Format: "HH:mm"
  final String endTime; // Format: "HH:mm"
  final DateTime createdAt;

  Training({
    this.id,
    required this.name,
    required this.weekdays,
    required this.startTime,
    required this.endTime,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'weekdays': weekdays.join(','),
      'startTime': startTime,
      'endTime': endTime,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Training.fromMap(Map<String, dynamic> map) {
    return Training(
      id: map['id'] as int?,
      name: map['name'] as String,
      weekdays: (map['weekdays'] as String)
          .split(',')
          .map((e) => int.parse(e))
          .toList(),
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Training copyWith({
    int? id,
    String? name,
    List<int>? weekdays,
    String? startTime,
    String? endTime,
    DateTime? createdAt,
  }) {
    return Training(
      id: id ?? this.id,
      name: name ?? this.name,
      weekdays: weekdays ?? this.weekdays,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Gibt die Wochentage als lesbare Strings zurück (Mo, Di, ...)
  String get weekdaysFormatted {
    const days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return weekdays.map((d) => days[d - 1]).join(' ');
  }
}
