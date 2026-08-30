import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../exercises/session_provider.dart';
import '../models/content.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';
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
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Katha'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _StatChip(
                icon: Icons.local_fire_department_rounded,
                value: '${progress.streak}',
                color: semantic.pacha,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: _StatChip(
                icon: Icons.star_rounded,
                value: '${progress.totalXp}',
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: content.units.length,
        itemBuilder: (context, index) {
          final unit = content.units[index];
          final lexemes = unit.lexemeIds;
          final known = progress.knownCount(Dimension.recognition, lexemes);
          final total = lexemes.length;
          final complete = total > 0 && known == total;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                final session = buildSessionForUnit(content: content, progress: progress, unit: unit);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SessionScreen(session: session, unitTitle: unit.title),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(unit.emoji ?? '📚', style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(unit.title, style: theme.textTheme.titleLarge),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : known / total,
                              minHeight: 6,
                              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation(complete ? semantic.pacha : theme.colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (complete)
                      Icon(Icons.check_circle_rounded, color: semantic.pacha)
                    else
                      Text('$known/$total', style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _StatChip({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
