import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xml/xml.dart';

class PlankoEntry {
  final int attendanceId;
  final String name;
  final String date;
  final String time;

  PlankoEntry({
    required this.attendanceId,
    required this.name,
    required this.date,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
        'attendanceId': attendanceId,
        'name': name,
        'date': date,
        'time': time,
      };

  factory PlankoEntry.fromJson(Map<String, dynamic> json) => PlankoEntry(
        attendanceId: json['attendanceId'] as int,
        name: json['name'] as String,
        date: json['date'] as String,
        time: json['time'] as String,
      );
}

class PlankoService {
  static const _templateAssetPath = 'assets/rtv_planko_template.docx';
  static const _currentPlankoFileName = 'current_planko.docx';
  static const _entriesFileName = 'planko_entries.json';
  static const _archiveDirName = 'planko_archive';

  Future<File?> ensureCurrentPlankoExists({String? customTemplatePath}) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final currentFile = File('${docDir.path}/$_currentPlankoFileName');
      if (await currentFile.exists()) return currentFile;

      final templateBytes = await _loadTemplateBytes(customTemplatePath);
      try {
        await _renderCurrentPlanko([], templateBytes, currentFile);
      } catch (_) {
        await currentFile.writeAsBytes(templateBytes, flush: true);
      }
      return currentFile;
    } catch (_) {
      return null;
    }
  }

  Future<File?> getCurrentPlanko({String? customTemplatePath}) async {
    return await ensureCurrentPlankoExists(customTemplatePath: customTemplatePath);
  }

  Future<void> rebuildCurrentPlanko({String? customTemplatePath}) async {
    final docDir = await getApplicationDocumentsDirectory();
    final currentFile = File('${docDir.path}/$_currentPlankoFileName');
    final templateBytes = await _loadTemplateBytes(customTemplatePath);
    final entries = await _loadEntries(docDir);
    await _renderCurrentPlanko(entries, templateBytes, currentFile);
  }

  Future<void> shareCurrentPlanko({String? customTemplatePath}) async {
    final file = await getCurrentPlanko(customTemplatePath: customTemplatePath);
    if (file == null) return;
    await Share.shareXFiles([XFile(file.path)], subject: 'Übungsleiter Planko');
  }

  Future<void> writeAttendanceEntry({
    required int attendanceId,
    required String name,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? timeNote,
    String? customTemplatePath,
  }) async {
    final docDir = await getApplicationDocumentsDirectory();
    final currentFile = File('${docDir.path}/$_currentPlankoFileName');
    await ensureCurrentPlankoExists(customTemplatePath: customTemplatePath);
    final templateBytes = await _loadTemplateBytes(customTemplatePath);

    final entries = await _loadEntries(docDir);
    final existingIndex =
        entries.indexWhere((e) => e.attendanceId == attendanceId);

    final capacity = _getTemplateCapacity(templateBytes);
    if (capacity > 0 && entries.length >= capacity) {
      await _archiveCurrentPlanko(currentFile);
      entries.clear();
    }

    final dateStr = _formatDate(date);
    final timeStr = timeNote == null || timeNote.isEmpty
        ? '$startTime - $endTime'
        : '$startTime - $endTime ($timeNote)';
    final entry = PlankoEntry(
      attendanceId: attendanceId,
      name: name,
      date: dateStr,
      time: timeStr,
    );
    if (existingIndex >= 0) {
      entries[existingIndex] = entry;
    } else {
      entries.add(entry);
    }

    await _saveEntries(docDir, entries);
    await _renderCurrentPlanko(entries, templateBytes, currentFile);
  }

  Future<void> removeAttendanceEntry({
    required int attendanceId,
    String? customTemplatePath,
  }) async {
    final docDir = await getApplicationDocumentsDirectory();
    final currentFile = File('${docDir.path}/$_currentPlankoFileName');
    final templateBytes = await _loadTemplateBytes(customTemplatePath);

    final entries = await _loadEntries(docDir);
    entries.removeWhere((e) => e.attendanceId == attendanceId);
    await _saveEntries(docDir, entries);
    await _renderCurrentPlanko(entries, templateBytes, currentFile);
  }

  Future<bool> validateTemplate(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final doc = _loadDocumentXml(bytes);
      final table = _findPlankoTable(doc);
      if (table == null) return false;
      final rows = _tableRows(table);
      return rows.length >= 2;
    } catch (_) {
      return false;
    }
  }

  Future<File?> createArchiveZip() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final archiveDir = Directory('${docDir.path}/$_archiveDirName');
      if (!await archiveDir.exists()) return null;

      final files = await archiveDir.list().toList();
      if (files.isEmpty) return null;

      final archive = Archive();
      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.docx')) {
          final fileName = entity.uri.pathSegments.last;
          final content = await entity.readAsBytes();
          archive.addFile(ArchiveFile(fileName, content.length, content));
        }
      }

      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) return null;

      final zipPath = '${docDir.path}/planko_archiv.zip';
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);
      return zipFile;
    } catch (_) {
      return null;
    }
  }

  Future<void> shareArchive() async {
    final zipFile = await createArchiveZip();
    if (zipFile != null) {
      await Share.shareXFiles([XFile(zipFile.path)],
          subject: 'Übungsleiter Planko Archiv');
    }
  }

  Future<List<File>> getArchivedPlankos() async {
    final docDir = await getApplicationDocumentsDirectory();
    final archiveDir = Directory('${docDir.path}/$_archiveDirName');
    if (!await archiveDir.exists()) return [];

    final files = <File>[];
    await for (final entity in archiveDir.list()) {
      if (entity is File && entity.path.endsWith('.docx')) {
        files.add(entity);
      }
    }

    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> clearArchive() async {
    final docDir = await getApplicationDocumentsDirectory();
    final archiveDir = Directory('${docDir.path}/$_archiveDirName');
    if (await archiveDir.exists()) {
      await archiveDir.delete(recursive: true);
    }
  }

  Future<void> _archiveCurrentPlanko(File currentFile) async {
    if (!await currentFile.exists()) return;
    final docDir = await getApplicationDocumentsDirectory();
    final archiveDir = Directory('${docDir.path}/$_archiveDirName');
    if (!await archiveDir.exists()) {
      await archiveDir.create(recursive: true);
    }
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final target = File('${archiveDir.path}/planko_$timestamp.docx');
    await currentFile.copy(target.path);
  }

  Future<List<int>> _loadTemplateBytes(String? customTemplatePath) async {
    if (customTemplatePath != null) {
      final file = File(customTemplatePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    }
    final data = await rootBundle.load(_templateAssetPath);
    return data.buffer.asUint8List();
  }

  Future<List<PlankoEntry>> _loadEntries(Directory docDir) async {
    final file = File('${docDir.path}/$_entriesFileName');
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    final decoded = jsonDecode(content) as List<dynamic>;
    return decoded
        .map((e) => PlankoEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveEntries(Directory docDir, List<PlankoEntry> entries) async {
    final file = File('${docDir.path}/$_entriesFileName');
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await file.writeAsString(encoded);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  int _getTemplateCapacity(List<int> templateBytes) {
    try {
      final doc = _loadDocumentXml(templateBytes);
      final table = _findPlankoTable(doc);
      if (table == null) return 40;
      final rows = _tableRows(table);
      if (rows.length <= 1) return 40;
      return rows.length - 1;
    } catch (_) {
      return 40;
    }
  }

  Future<void> _renderCurrentPlanko(
    List<PlankoEntry> entries,
    List<int> templateBytes,
    File outputFile,
  ) async {
    final archive = ZipDecoder().decodeBytes(templateBytes);
    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => ArchiveFile('word/document.xml', 0, []),
    );

    final xmlString = utf8.decode(docFile.content as List<int>);
    final document = XmlDocument.parse(xmlString);
    final table = _findPlankoTable(document);
    if (table == null) {
      await outputFile.writeAsBytes(templateBytes);
      return;
    }

    final rows = _tableRows(table);
    if (rows.isEmpty) {
      await outputFile.writeAsBytes(templateBytes);
      return;
    }

    final header = rows.first;
    final rowTemplate = rows.length > 1 ? rows[1].copy() : header.copy();

    final retainedChildren = <XmlNode>[];
    for (final node in table.children) {
      if (node is XmlElement && node.name.local == 'tr') {
        if (node == header) {
          retainedChildren.add(node);
        }
      } else {
        retainedChildren.add(node);
      }
    }
    table.children
      ..clear()
      ..addAll(retainedChildren);

    for (final entry in entries) {
      final row = rowTemplate.copy();
      final cells = row
          .descendants
          .whereType<XmlElement>()
          .where((e) => e.name.local == 'tc')
          .toList();
      if (cells.length >= 3) {
        _setCellText(cells[0], entry.name);
        _setCellText(cells[1], entry.date);
        _setCellText(cells[2], entry.time);
      }
      table.children.add(row);
    }

    final updatedXml = document.toXmlString();
    final updatedBytes = utf8.encode(updatedXml);

    final newArchive = Archive();
    for (final file in archive.files) {
      if (file.name == 'word/document.xml') continue;
      newArchive.addFile(file);
    }
    newArchive.addFile(
      ArchiveFile(
        'word/document.xml',
        updatedBytes.length,
        updatedBytes,
      ),
    );

    final zipData = ZipEncoder().encode(newArchive);
    if (zipData == null) return;
    await outputFile.writeAsBytes(zipData, flush: true);
  }

  XmlDocument _loadDocumentXml(List<int> templateBytes) {
    final archive = ZipDecoder().decodeBytes(templateBytes);
    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => ArchiveFile('word/document.xml', 0, []),
    );
    final xmlString = utf8.decode(docFile.content as List<int>);
    return XmlDocument.parse(xmlString);
  }

  XmlElement? _findPlankoTable(XmlDocument document) {
    final tables = document
        .descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'tbl');
    for (final table in tables) {
      final rows = _tableRows(table);
      if (rows.isEmpty) continue;
      final headerText = _rowText(rows.first).toLowerCase();
      if (headerText.contains('angebot') &&
          headerText.contains('termin') &&
          headerText.contains('uhrzeit')) {
        return table;
      }
    }
    return null;
  }

  List<XmlElement> _tableRows(XmlElement table) {
    return table.children
        .whereType<XmlElement>()
        .where((e) => e.name.local == 'tr')
        .toList();
  }

  String _rowText(XmlElement row) {
    return row
        .descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 't')
        .map((e) => e.innerText)
        .join(' ');
  }

  void _setCellText(XmlElement cell, String text) {
    final textNodes = cell
        .descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == 't')
        .toList();
    if (textNodes.isEmpty) {
      final p = XmlElement(XmlName('w:p'));
      final r = XmlElement(XmlName('w:r'));
      final t = XmlElement(XmlName('w:t'));
      t.children.add(XmlText(text));
      r.children.add(t);
      p.children.add(r);
      cell.children.add(p);
      return;
    }
    for (int i = 0; i < textNodes.length; i++) {
      textNodes[i].children
        ..clear()
        ..add(i == 0 ? XmlText(text) : XmlText(''));
    }
  }
}
