/// Status der Anwesenheit
enum AttendanceStatus {
  pending, // Noch nicht beantwortet
  present, // Pünktlich
  absent, // Nicht anwesend
  late, // Zu spät
  leftEarly, // Früher gegangen
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
  final int leftEarlyMinutes;
  final String? nameSnapshot;
  final String? startTimeSnapshot;
  final String? endTimeSnapshot;

  Attendance({
    this.id,
    this.trainingId,
    this.eventId,
    required this.date,
    this.status = AttendanceStatus.pending,
    this.answeredAt,
    this.lateMinutes = 0,
    this.leftEarlyMinutes = 0,
    this.nameSnapshot,
    this.startTimeSnapshot,
    this.endTimeSnapshot,
  }) : assert(
         trainingId != null || eventId != null,
         'Entweder trainingId oder eventId muss gesetzt sein',
       );

  bool get isTraining => trainingId != null;
  bool get isEvent => eventId != null;
  bool get isPending => status == AttendanceStatus.pending;
  bool get isAnswered => status != AttendanceStatus.pending;
  bool get isPresentLike =>
      status == AttendanceStatus.present ||
      status == AttendanceStatus.late ||
      status == AttendanceStatus.leftEarly;
  bool get isLate => status == AttendanceStatus.late;
  bool get isLeftEarly => status == AttendanceStatus.leftEarly;
  bool get isAbsent => status == AttendanceStatus.absent;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trainingId': trainingId,
      'eventId': eventId,
      'date': date.toIso8601String(),
      'status': status.index,
      'answeredAt': answeredAt?.toIso8601String(),
      'lateMinutes': lateMinutes,
      'leftEarlyMinutes': leftEarlyMinutes,
      'nameSnapshot': nameSnapshot,
      'startTimeSnapshot': startTimeSnapshot,
      'endTimeSnapshot': endTimeSnapshot,
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
      leftEarlyMinutes: (map['leftEarlyMinutes'] as int?) ?? 0,
      nameSnapshot: map['nameSnapshot'] as String?,
      startTimeSnapshot: map['startTimeSnapshot'] as String?,
      endTimeSnapshot: map['endTimeSnapshot'] as String?,
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
    int? leftEarlyMinutes,
    String? nameSnapshot,
    String? startTimeSnapshot,
    String? endTimeSnapshot,
  }) {
    return Attendance(
      id: id ?? this.id,
      trainingId: trainingId ?? this.trainingId,
      eventId: eventId ?? this.eventId,
      date: date ?? this.date,
      status: status ?? this.status,
      answeredAt: answeredAt ?? this.answeredAt,
      lateMinutes: lateMinutes ?? this.lateMinutes,
      leftEarlyMinutes: leftEarlyMinutes ?? this.leftEarlyMinutes,
      nameSnapshot: nameSnapshot ?? this.nameSnapshot,
      startTimeSnapshot: startTimeSnapshot ?? this.startTimeSnapshot,
      endTimeSnapshot: endTimeSnapshot ?? this.endTimeSnapshot,
    );
  }

  String? timeNote() {
    if (status == AttendanceStatus.late && lateMinutes > 0) {
      return '+$lateMinutes min';
    }
    if (status == AttendanceStatus.leftEarly && leftEarlyMinutes > 0) {
      return '-$leftEarlyMinutes min';
    }
    return null;
  }
}
