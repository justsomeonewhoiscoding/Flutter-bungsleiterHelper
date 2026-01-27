import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../services/planko_service.dart';
import 'onboarding_screen.dart';
import 'archive_screen.dart';
import '../utils/app_strings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(strings.settingsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: strings.featuresOverview,
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => OnboardingScreen()));
            },
          ),
        ],
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
                  title: strings.documentSection,
                  children: [
                    _SettingsButton(
                      label: strings.selectTemplate,
                      isPrimary: true,
                      onTap: () => _selectTemplate(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.settings.customTemplatePath != null
                          ? strings.customTemplateSelected
                          : strings.defaultTemplateUsed,
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
                  title: strings.archiveSection,
                  children: [
                    _SettingsButton(
                      label: strings.openPlanko,
                      isPrimary: true,
                      onTap: () => _openPlanko(context),
                    ),
                    const SizedBox(height: 8),
                    _SettingsButton(
                      label: strings.sharePlanko,
                      onTap: () => _sharePlanko(context),
                    ),
                    const SizedBox(height: 8),
                    _SettingsButton(
                      label: strings.shareArchive,
                      onTap: () => _shareArchive(context),
                    ),
                    const SizedBox(height: 8),
                    _SettingsButton(
                      label: strings.manageArchive,
                      onTap: () => _manageArchive(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Sprache Section
                _SectionCard(
                  title: strings.languageSection,
                  children: [
                    Text(
                      strings.currentLanguage(
                        provider.settings.language == 'de'
                            ? 'Deutsch'
                            : provider.settings.language == 'en'
                            ? 'English'
                            : strings.systemLanguage,
                      ),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    _SettingsButton(
                      label: strings.changeLanguage,
                      onTap: () => _changeLanguage(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Gefahrenzone
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.errorColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.dangerZone,
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.dangerZoneSubtitle,
                        style: TextStyle(
                          color: AppTheme.errorColor.withValues(alpha: 0.8),
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
                          label: Text(
                            strings.rewritePlanko,
                            style: const TextStyle(color: AppTheme.errorColor),
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
    final strings = AppStrings.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    if (!context.mounted) return;

    if (result != null && result.files.single.path != null) {
      final plankoService = PlankoService();
      final isValid = await plankoService.validateTemplate(
        result.files.single.path!,
      );
      if (!isValid) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.templateInvalid)),
        );
        return;
      }
      if (!context.mounted) return;
      final provider = context.read<AppProvider>();
      await provider.updateSettings(
        provider.settings.copyWith(
          customTemplatePath: result.files.single.path,
        ),
      );
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.templateSaved)),
      );
    }
  }

  void _openPlanko(BuildContext context) async {
    final strings = AppStrings.of(context);
    final plankoService = PlankoService();
    final provider = context.read<AppProvider>();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.plankoCreating)));

    final file = await plankoService.getCurrentPlanko(
      customTemplatePath: provider.settings.customTemplatePath,
    );

    if (!context.mounted) return;
    if (file == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.currentPlankoMissing)),
      );
      return;
    }
    await OpenFilex.open(file.path);
  }

  void _sharePlanko(BuildContext context) async {
    final strings = AppStrings.of(context);
    final plankoService = PlankoService();
    final provider = context.read<AppProvider>();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.plankoCreating)));
    await plankoService.shareCurrentPlanko(
      customTemplatePath: provider.settings.customTemplatePath,
    );
  }

  void _shareArchive(BuildContext context) async {
    final strings = AppStrings.of(context);
    final plankoService = PlankoService();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.archiveCreating)));

    await plankoService.shareArchive();
  }

  void _manageArchive(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ArchiveScreen()),
    );
  }

  void _changeLanguage(BuildContext context) {
    final strings = AppStrings.of(context);
    final provider = context.read<AppProvider>();
    final currentLang = provider.settings.language;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.chooseLanguage),
        content: RadioGroup<String>(
          groupValue: currentLang,
          onChanged: (value) {
            if (value == null) return;
            provider.updateSettings(
              provider.settings.copyWith(language: value),
            );
            Navigator.pop(ctx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Deutsch'),
                leading: Radio<String>(value: 'de'),
              ),
              const ListTile(
                title: Text('English'),
                leading: Radio<String>(value: 'en'),
              ),
              ListTile(
                title: Text(strings.systemLanguage),
                leading: const Radio<String>(value: 'system'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context) {
    final strings = AppStrings.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteAllTitle),
        content: Text(strings.deleteAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<AppProvider>().resetAllData();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(strings.allDataDeleted)),
              );
            },
            child: Text(
              strings.delete,
              style: const TextStyle(color: AppTheme.errorColor),
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
                  color: AppTheme.textSecondary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(label),
            ),
    );
  }
}
