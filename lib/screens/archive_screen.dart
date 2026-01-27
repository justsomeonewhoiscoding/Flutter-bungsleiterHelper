import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../services/planko_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  late Future<List<File>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = PlankoService().getArchivedPlankos();
  }

  void _refresh() {
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.archiveSection),
      ),
      body: FutureBuilder<List<File>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final files = snapshot.data!;
          if (files.isEmpty) {
            return Center(
              child: Text(
                strings.noEntries,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final name = file.path.split('/').last;
              final sizeKb = (file.lengthSync() / 1024).round();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(name),
                  subtitle: Text('$sizeKb KB'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.open_in_new),
                        onPressed: () => OpenFilex.open(file.path),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () =>
                            Share.shareXFiles([XFile(file.path)]),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await PlankoService().shareArchive();
                  },
                  child: Text(strings.shareArchive),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    await PlankoService().clearArchive();
                    _refresh();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: AppTheme.textPrimary,
                  ),
                  child: Text(strings.deleteArchive),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
