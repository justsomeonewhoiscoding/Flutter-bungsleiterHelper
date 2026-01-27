/// Status der Anwesenheit
enum AttendanceStatus {
  pending, // Noch nicht beantwortet
  present, // Ja, war da
  absent, // Nein, war nicht da
}

/// Model für Anwesenheits-Einträge
class Attendance {
  final int? id;
  final int? trainingId; // Entweder Training ODER Event
  final int? eventId;
  final DateTime date;
  final AttendanceStatus status;
  final DateTime? answeredAt;
  final int lateMinutes;

  Attendance({
    this.id,
    this.trainingId,
    this.eventId,
    required this.date,
    this.status = AttendanceStatus.pending,
    this.answeredAt,
    this.lateMinutes = 0,
  }) : assert(
         trainingId != null || eventId != null,
         'Entweder trainingId oder eventId muss gesetzt sein',
       );

  bool get isTraining => trainingId != null;
  bool get isEvent => eventId != null;
  bool get isPending => status == AttendanceStatus.pending;
  bool get isAnswered => status != AttendanceStatus.pending;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trainingId': trainingId,
      'eventId': eventId,
      'date': date.toIso8601String(),
      'status': status.index,
      'answeredAt': answeredAt?.toIso8601String(),
      'lateMinutes': lateMinutes,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] as int?,
      trainingId: map['trainingId'] as int?,
      eventId: map['eventId'] as int?,
      date: DateTime.parse(map['date'] as String),
      status: AttendanceStatus.values[map['status'] as int],
      answeredAt: map['answeredAt'] != null
          ? DateTime.parse(map['answeredAt'] as String)
          : null,
      lateMinutes: (map['lateMinutes'] as int?) ?? 0,
    );
  }

  Attendance copyWith({
    int? id,
    int? trainingId,
    int? eventId,
    DateTime? date,
    AttendanceStatus? status,
    DateTime? answeredAt,
    int? lateMinutes,
  }) {
    return Attendance(
      id: id ?? this.id,
      trainingId: trainingId ?? this.trainingId,
      eventId: eventId ?? this.eventId,
      date: date ?? this.date,
      status: status ?? this.status,
      answeredAt: answeredAt ?? this.answeredAt,
      lateMinutes: lateMinutes ?? this.lateMinutes,
    );
  }
}
