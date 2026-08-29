import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../exercises/session_provider.dart';
import '../models/content.dart';
import '../services/progress_service.dart';
import 'session_screen.dart';

/// Unit picker (replaces the old category deck picker 1:1 -- the 9
/// legacy units are exactly the old 9 categories, see
/// scripts/migrate_word_bank.py). Unit selection isn't a DAG walk yet
/// since all legacy units are flat with no prerequisites; that UI
/// arrives with Phase C's real A-G section structure (STRATEGY sec 3, 5).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.watch<ContentBundle>();
    final progress = context.watch<ProgressService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Katha'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, size: 20),
                  const SizedBox(width: 4),
                  Text('${progress.streak}'),
                  const SizedBox(width: 12),
                  const Icon(Icons.star, size: 20),
                  const SizedBox(width: 4),
                  Text('${progress.totalXp}'),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: content.units.length,
        itemBuilder: (context, index) {
          final unit = content.units[index];
          final lexemes = unit.lexemeIds;
          final known = progress.knownCount(Dimension.recognition, lexemes);
          final total = lexemes.length;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Text(unit.emoji ?? '📚', style: const TextStyle(fontSize: 28)),
              title: Text(unit.title, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : known / total,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              trailing: Text('$known/$total', style: Theme.of(context).textTheme.bodySmall),
              onTap: () {
                final session = buildSessionForUnit(content: content, progress: progress, unit: unit);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SessionScreen(session: session, unitTitle: unit.title),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
