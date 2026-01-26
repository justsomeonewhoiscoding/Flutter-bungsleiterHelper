import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../services/planko_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Einstellungen'),
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dokument Section
                _SectionCard(
                  title: 'Dokument',
                  children: [
                    _SettingsButton(
                      label: 'DOCX-Template auswählen',
                      isPrimary: true,
                      onTap: () => _selectTemplate(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.settings.customTemplatePath != null
                          ? 'Custom Template ausgewählt'
                          : 'Standard RTV-DOCX Template wird genutzt',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Archiv Section
                _SectionCard(
                  title: 'Archiv',
                  children: [
                    _SettingsButton(
                      label: 'Aktuelles Planko öffnen',
                      isPrimary: true,
                      onTap: () => _openPlanko(context),
                    ),
                    const SizedBox(height: 8),
                    _SettingsButton(
                      label: 'Aktuelles Planko teilen / speichern',
                      onTap: () => _sharePlanko(context),
                    ),
                    const SizedBox(height: 8),
                    _SettingsButton(
                      label: 'Archiv als ZIP teilen',
                      onTap: () => _shareArchive(context),
                    ),
                    const SizedBox(height: 8),
                    _SettingsButton(
                      label: 'Archiv verwalten',
                      onTap: () => _manageArchive(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Sprache Section
                _SectionCard(
                  title: 'Sprache',
                  children: [
                    Text(
                      'Aktuelle Sprache: ${provider.settings.language == 'de' ? 'Deutsch' : 'English'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    _SettingsButton(
                      label: 'Sprache ändern',
                      onTap: () => _changeLanguage(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Gefahrenzone
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.errorColor.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Gefahrenzone',
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Diese Aktion kann nicht rückgängig gemacht werden.',
                        style: TextStyle(
                          color: AppTheme.errorColor.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmReset(context),
                          icon: const Icon(
                            Icons.refresh,
                            color: AppTheme.errorColor,
                          ),
                          label: const Text(
                            'Planko neu schreiben',
                            style: TextStyle(color: AppTheme.errorColor),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.errorColor),
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _selectTemplate(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );

    if (result != null && result.files.single.path != null) {
      final provider = context.read<AppProvider>();
      await provider.updateSettings(
        provider.settings.copyWith(
          customTemplatePath: result.files.single.path,
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template wurde gespeichert')),
      );
    }
  }

  void _openPlanko(BuildContext context) async {
    final now = DateTime.now();
    final plankoService = PlankoService();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Planko wird erstellt...')));

    final file = await plankoService.generateMonthlyPlanko(
      year: now.year,
      month: now.month,
    );

    if (file != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Planko erstellt: ${file.path.split('/').last}'),
        ),
      );
    }
  }

  void _sharePlanko(BuildContext context) async {
    final now = DateTime.now();
    final plankoService = PlankoService();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Planko wird erstellt...')));

    final file = await plankoService.generateMonthlyPlanko(
      year: now.year,
      month: now.month,
    );

    if (file != null) {
      await plankoService.sharePlanko(file);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Erstellen des Planko')),
      );
    }
  }

  void _shareArchive(BuildContext context) async {
    final plankoService = PlankoService();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Archiv wird erstellt...')));

    await plankoService.shareArchive();
  }

  void _manageArchive(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archiv verwalten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Test-Benachrichtigung'),
              onTap: () async {
                Navigator.pop(ctx);
                final notificationService = NotificationService();
                // Erst Berechtigung anfordern
                final granted = await notificationService.requestPermission();
                if (granted) {
                  await notificationService.showTestNotification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Benachrichtigung gesendet')),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Benachrichtigungsberechtigung wurde nicht erteilt'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_forever,
                color: AppTheme.errorColor,
              ),
              title: const Text('Archiv löschen'),
              onTap: () async {
                await PlankoService().clearArchive();
                Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Archiv gelöscht')),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  void _changeLanguage(BuildContext context) {
    final provider = context.read<AppProvider>();
    final currentLang = provider.settings.language;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sprache wählen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Deutsch'),
              leading: Radio<String>(
                value: 'de',
                groupValue: currentLang,
                onChanged: (value) {
                  provider.updateSettings(
                    provider.settings.copyWith(language: value),
                  );
                  Navigator.pop(ctx);
                },
              ),
            ),
            ListTile(
              title: const Text('English'),
              leading: Radio<String>(
                value: 'en',
                groupValue: currentLang,
                onChanged: (value) {
                  provider.updateSettings(
                    provider.settings.copyWith(language: value),
                  );
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alle Daten löschen?'),
        content: const Text(
          'Alle Trainings, Events und Anwesenheitseinträge werden unwiderruflich gelöscht. Diese Aktion kann nicht rückgängig gemacht werden!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              context.read<AppProvider>().resetAllData();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Alle Daten wurden gelöscht')),
              );
            },
            child: const Text(
              'Löschen',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  const _SettingsButton({
    required this.label,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: isPrimary
          ? ElevatedButton(onPressed: onTap, child: Text(label))
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(
                  color: AppTheme.textSecondary.withOpacity(0.3),
                ),
              ),
              child: Text(label),
            ),
    );
  }
}
