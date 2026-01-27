import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/app_provider.dart';
import 'theme/app_theme.dart';
import 'screens/screens.dart';
import 'screens/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'utils/app_strings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await initializeDateFormatting('de_DE', null);
  await NotificationService().init();

  final prefs = await SharedPreferences.getInstance();
  final seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

  // Default Planko-Template kopieren, falls kein Custom-Template gewählt
  final customTemplatePath = prefs.getString('customTemplatePath');
  if (customTemplatePath == null) {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final targetPath = '${docDir.path}/rtv_planko_template.docx';
      final assetData = await rootBundle.load(
        'assets/rtv_planko_template.docx',
      );
      final bytes = assetData.buffer.asUint8List();
      final file = File(targetPath);
      await file.writeAsBytes(bytes);
      await prefs.setString('customTemplatePath', targetPath);
    } catch (e) {
      // Fehler ignorieren, falls Asset nicht gefunden
    }
  }

  runApp(MyApp(showOnboarding: !seenOnboarding));
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  const MyApp({super.key, this.showOnboarding = false});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider()..init(),
      child: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final strings = AppStrings.forLanguage(provider.settings.language);
          return MaterialApp(
            title: strings.appTitle,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            home: showOnboarding
                ? OnboardingScreen(
                    onFinish: (context) async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('seenOnboarding', true);
                      if (!context.mounted) return;
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    },
                  )
                : const HomeScreen(),
            routes: {
              '/battery_optimization': (context) =>
                  const _BatteryOptimizationScreen(),
            },
          );
        },
      ),
    );
  }
}


class _BatteryOptimizationScreen extends StatelessWidget {
  const _BatteryOptimizationScreen();

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid) {
      Future.delayed(const Duration(milliseconds: 200), () async {
        const intent = MethodChannel('uebungsleiter_helper/battery_optimization');
        try {
          await intent.invokeMethod('openBatteryOptimization');
        } catch (_) {}
        if (!context.mounted) return;
        Navigator.pop(context);
      });
    }
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Öffne Akku-Optimierung...'),
          ],
        ),
      ),
    );
  }
}
