/// Model für wiederkehrende Trainings
class Training {
  final int? id;
  final String name;
  final List<int> weekdays; // 1=Mo, 2=Di, ..., 7=So
  final String startTime; // Format: "HH:mm"
  final String endTime; // Format: "HH:mm"
  final DateTime createdAt;
  final bool isActive;

  Training({
    this.id,
    required this.name,
    required this.weekdays,
    required this.startTime,
    required this.endTime,
    DateTime? createdAt,
    this.isActive = true,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'weekdays': weekdays.join(','),
      'startTime': startTime,
      'endTime': endTime,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
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
      isActive: (map['isActive'] as int? ?? 1) == 1,
    );
  }

  Training copyWith({
    int? id,
    String? name,
    List<int>? weekdays,
    String? startTime,
    String? endTime,
    DateTime? createdAt,
    bool? isActive,
  }) {
    return Training(
      id: id ?? this.id,
      name: name ?? this.name,
      weekdays: weekdays ?? this.weekdays,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Gibt die Wochentage als lesbare Strings zurück (Mo, Di, ...)
  String get weekdaysFormatted {
    const days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return weekdays.map((d) => days[d - 1]).join(' ');
  }

  int get weekdaysMask {
    int mask = 0;
    for (final day in weekdays) {
      mask |= 1 << (day - 1);
    }
    return mask;
  }

  int get startMinutes {
    final parts = startTime.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  int get endMinutes {
    final parts = endTime.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}
