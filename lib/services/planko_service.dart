import 'dart:io';
import 'package:docx_template/docx_template.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive.dart';
import '../models/models.dart';
import 'database_service.dart';

class PlankoService {
  final DatabaseService _db = DatabaseService();

  /// Generiert ein Planko (DOCX) für einen bestimmten Monat
  Future<File?> generateMonthlyPlanko({
    required int year,
    required int month,
    String? customTemplatePath,
  }) async {
    try {
      final trainings = await _db.getAllTrainings();
      final events = await _db.getAllEvents();

      // Hole alle Anwesenheitseinträge für den Monat
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0); // Letzter Tag des Monats

      final allAttendance = await _db.getAllAttendance();
      final monthAttendance = allAttendance.where((a) {
        return a.date.year == year && a.date.month == month;
      }).toList();

      // Erstelle Daten für das Dokument
      final rows = <Map<String, dynamic>>[];

      for (final attendance in monthAttendance) {
        String name = '';
        String type = '';

        if (attendance.trainingId != null) {
          final training = trainings.firstWhere(
            (t) => t.id == attendance.trainingId,
            orElse: () => Training(
              name: 'Unbekannt',
              weekdays: [],
              startTime: '',
              endTime: '',
            ),
          );
          name = training.name;
          type = 'Training';
        } else if (attendance.eventId != null) {
          final event = events.firstWhere(
            (e) => e.id == attendance.eventId,
            orElse: () => Event(
              name: 'Unbekannt',
              date: DateTime.now(),
              startTime: '',
              endTime: '',
            ),
          );
          name = event.name;
          type = 'Event';
        }

        rows.add({
          'datum': DateFormat('dd.MM.yyyy').format(attendance.date),
          'name': name,
          'typ': type,
          'anwesend': attendance.status == AttendanceStatus.present
              ? 'Ja'
              : attendance.status == AttendanceStatus.absent
              ? 'Nein'
              : '-',
        });
      }

      // Sortiere nach Datum
      rows.sort((a, b) => a['datum'].compareTo(b['datum']));

      // Erstelle einfaches Text-basiertes Dokument falls kein Template
      final directory = await getApplicationDocumentsDirectory();
      final plankoDir = Directory('${directory.path}/planko');
      if (!await plankoDir.exists()) {
        await plankoDir.create(recursive: true);
      }

      final monthName = DateFormat(
        'MMMM yyyy',
        'de_DE',
      ).format(DateTime(year, month));
      final fileName = 'Planko_${year}_${month.toString().padLeft(2, '0')}.txt';
      final filePath = '${plankoDir.path}/$fileName';

      // Erstelle Text-Report
      final buffer = StringBuffer();
      buffer.writeln(
        '═══════════════════════════════════════════════════════════',
      );
      buffer.writeln('              ÜBUNGSLEITER PLANKO - $monthName');
      buffer.writeln(
        '═══════════════════════════════════════════════════════════',
      );
      buffer.writeln('');
      buffer.writeln(
        'Erstellt am: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
      );
      buffer.writeln('');
      buffer.writeln(
        '───────────────────────────────────────────────────────────',
      );
      buffer.writeln('ÜBERSICHT');
      buffer.writeln(
        '───────────────────────────────────────────────────────────',
      );

      final presentCount = monthAttendance
          .where((a) => a.status == AttendanceStatus.present)
          .length;
      final absentCount = monthAttendance
          .where((a) => a.status == AttendanceStatus.absent)
          .length;
      final pendingCount = monthAttendance
          .where((a) => a.status == AttendanceStatus.pending)
          .length;

      buffer.writeln('Anwesend:     $presentCount');
      buffer.writeln('Abwesend:     $absentCount');
      buffer.writeln('Offen:        $pendingCount');
      buffer.writeln('Gesamt:       ${monthAttendance.length}');
      buffer.writeln('');
      buffer.writeln(
        '───────────────────────────────────────────────────────────',
      );
      buffer.writeln('DETAILS');
      buffer.writeln(
        '───────────────────────────────────────────────────────────',
      );
      buffer.writeln('');
      buffer.writeln('Datum        | Training/Event              | Status');
      buffer.writeln('─────────────┼─────────────────────────────┼────────');

      for (final row in rows) {
        final datum = row['datum'].toString().padRight(12);
        final name = row['name'].toString().padRight(28).substring(0, 28);
        final status = row['anwesend'];
        buffer.writeln('$datum | $name | $status');
      }

      buffer.writeln('');
      buffer.writeln(
        '═══════════════════════════════════════════════════════════',
      );

      final file = File(filePath);
      await file.writeAsString(buffer.toString());

      return file;
    } catch (e) {
      print('Fehler beim Erstellen des Planko: $e');
      return null;
    }
  }

  /// Teilt das aktuelle Planko
  Future<void> sharePlanko(File file) async {
    await Share.shareXFiles([XFile(file.path)], subject: 'Übungsleiter Planko');
  }

  /// Erstellt ein ZIP-Archiv aller Plankos
  Future<File?> createArchiveZip() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final plankoDir = Directory('${directory.path}/planko');

      if (!await plankoDir.exists()) {
        return null;
      }

      final files = await plankoDir.list().toList();
      if (files.isEmpty) return null;

      final archive = Archive();

      for (final entity in files) {
        if (entity is File) {
          final fileName = entity.path.split('/').last;
          final content = await entity.readAsBytes();
          archive.addFile(ArchiveFile(fileName, content.length, content));
        }
      }

      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) return null;

      final zipPath = '${directory.path}/planko_archiv.zip';
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);

      return zipFile;
    } catch (e) {
      print('Fehler beim Erstellen des Archivs: $e');
      return null;
    }
  }

  /// Teilt das Archiv
  Future<void> shareArchive() async {
    final zipFile = await createArchiveZip();
    if (zipFile != null) {
      await Share.shareXFiles([
        XFile(zipFile.path),
      ], subject: 'Übungsleiter Planko Archiv');
    }
  }

  /// Holt alle gespeicherten Plankos
  Future<List<File>> getArchivedPlankos() async {
    final directory = await getApplicationDocumentsDirectory();
    final plankoDir = Directory('${directory.path}/planko');

    if (!await plankoDir.exists()) {
      return [];
    }

    final files = <File>[];
    await for (final entity in plankoDir.list()) {
      if (entity is File && entity.path.endsWith('.txt')) {
        files.add(entity);
      }
    }

    // Nach Datum sortieren (neueste zuerst)
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  /// Löscht alle archivierten Plankos
  Future<void> clearArchive() async {
    final directory = await getApplicationDocumentsDirectory();
    final plankoDir = Directory('${directory.path}/planko');

    if (await plankoDir.exists()) {
      await plankoDir.delete(recursive: true);
    }
  }
}
