import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/word_bank.dart';
import '../models/word.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';
import 'flashcard_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Katha', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 4),
                Text('${progress.streak}', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 16),
                const Text('⭐', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 4),
                Text('${progress.totalXp}', style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Namaste! 👋', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'Pick a deck to practice some Telugu.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
            const SizedBox(height: 20),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.05,
              children: [
                for (final category in WordBank.categories)
                  _DeckCard(
                    category: category,
                    progress: progress,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => FlashcardScreen(category: category)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckCard extends StatelessWidget {
  final Category category;
  final ProgressService progress;
  final VoidCallback onTap;

  const _DeckCard({required this.category, required this.progress, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final words = WordBank.wordsForCategory(category.id);
    final due = progress.dueWords(words).length;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category.emoji, style: const TextStyle(fontSize: 32)),
              const Spacer(),
              Text(category.label, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 17)),
              const SizedBox(height: 4),
              Text(
                due > 0 ? '$due to review' : 'All caught up',
                style: TextStyle(
                  color: due > 0 ? AppColors.maroon : Colors.grey.shade500,
                  fontWeight: due > 0 ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
