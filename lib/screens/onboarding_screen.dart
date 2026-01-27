import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  final Future<void> Function(BuildContext context)? onFinish;
  const OnboardingScreen({super.key, this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ÜbungsleiterHelper – Funktionsübersicht'),
        automaticallyImplyLeading: false,
      ),
      body: Scrollbar(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.red[50],
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.battery_alert, color: Colors.red[400]),
                        const SizedBox(width: 8),
                        const Text(
                          'Akku-Optimierung',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Damit Erinnerungen zuverlässig funktionieren, deaktiviere die Akku-Optimierung für ÜbungsleiterHelper in den Android-Einstellungen.',
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.settings),
                      label: const Text('Akku-Optimierung jetzt öffnen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[300],
                      ),
                      onPressed: () async {
                        // Öffne die Akku-Optimierungs-Einstellungen (nur Android)
                        try {
                          await Future.delayed(const Duration(milliseconds: 100));
                          if (!context.mounted) return;
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Hinweis'),
                              content: const Text(
                                'Du wirst jetzt zu den Akku-Einstellungen weitergeleitet. Suche dort nach "Akku-Optimierung" und setze die App auf "Nicht optimiert".',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                          await Future.delayed(const Duration(milliseconds: 500));
                          if (!context.mounted) return;
                          // Android Intent
                          Navigator.of(context).pushNamed('/battery_optimization');
                        } catch (_) {}
                      },
                    ),
                  ],
                ),
              ),
            ),
            _SectionCard(
              title: 'Trainingsverwaltung',
              children: [
                _bullet('Trainings anlegen, bearbeiten, löschen'),
                _bullet(
                  'Wöchentliche Wiederholung, flexible Zeit- und Wochentagswahl',
                ),
                _bullet('Einmalige Events können separat hinzugefügt werden'),
                _bullet('Rückwirkendes Eintragen von Trainings möglich'),
                _bullet(
                  'Übersicht der letzten 5 Trainings beim Erstellen eines neuen Trainings',
                ),
              ],
            ),
            _SectionCard(
              title: 'Anwesenheitsmanagement',
              children: [
                _bullet('Teilnehmer pro Training verwalten'),
                _bullet('Anwesenheit, Abwesenheit, unentschieden markieren'),
                _bullet('Verspätung erfassen (nur bei „anwesend“)'),
                _bullet(
                  'Historie pro Training: Übersicht aller bisherigen Anwesenheiten',
                ),
                _bullet(
                  'Änderungen an der Historie wirken sich auf Archive aus',
                ),
              ],
            ),
            _SectionCard(
              title: 'Archive & Berichte',
              children: [
                _bullet('Trainings und Anwesenheiten werden archiviert'),
                _bullet(
                  'Export als DOCX (Planko), optional mit Verspätungsangaben',
                ),
                _bullet('Planko kann direkt geöffnet oder geteilt werden'),
                _bullet(
                  'Planko kann per Button geleert und neu geschrieben werden',
                ),
              ],
            ),
            _SectionCard(
              title: 'Sprache & Barrierefreiheit',
              children: [
                _bullet('App-Sprache unabhängig von Systemsprache einstellbar'),
                _bullet('Hoher Kontrast, große Schrift, klare Icons'),
                _bullet(
                  'Alle Status sind farblich und per Layout unterscheidbar',
                ),
              ],
            ),
            _SectionCard(
              title: 'Einstellungen',
              children: [
                _bullet('Übersichtliche Kartenstruktur'),
                _bullet('Sprache, Benachrichtigungen, Datenverwaltung'),
                _bullet('Spracheinstellung bleibt erhalten'),
              ],
            ),
            _SectionCard(
              title: 'Sicherheit & Bedienkomfort',
              children: [
                _bullet('Löschen von Daten immer mit Bestätigungsdialog'),
                _bullet(
                  'Systemsteuerungselemente werden während der Nutzung ausgeblendet',
                ),
                _bullet(
                  'Back-Button und Top-Bar sind auf allen Screens sichtbar',
                ),
              ],
            ),
            _SectionCard(
              title: 'FAQ',
              children: [
                _faq(
                  'Kann ich Trainings rückwirkend eintragen?',
                  'Ja, das ist möglich.',
                ),
                _faq(
                  'Kann ich die App auf Englisch nutzen?',
                  'Ja, Sprache kann in den Einstellungen unabhängig vom System gewählt werden.',
                ),
                _faq(
                  'Wie gebe ich Verspätungen ein?',
                  'Im Anwesenheitsdialog auf „Verspätung“ tippen, dann per Scrollrad Stunden/Minuten wählen.',
                ),
                _faq(
                  'Was passiert beim Löschen?',
                  'Es erscheint immer ein Bestätigungsdialog, um versehentliches Löschen zu verhindern.',
                ),
                _faq(
                  'Wie funktioniert der Export?',
                  'Im Archiv kann das aktuelle Planko-Dokument erstellt, geöffnet oder geteilt werden.',
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                if (onFinish != null) {
                  await onFinish!(context);
                } else {
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Fertig'),
            ),
          ],
        ),
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

Widget _bullet(String text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 2),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('• ', style: TextStyle(fontSize: 16)),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
    ],
  ),
);

Widget _faq(String question, String answer) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(question, style: const TextStyle(fontWeight: FontWeight.bold)),
      Text(answer),
    ],
  ),
);
