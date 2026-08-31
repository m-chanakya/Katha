import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/progress_service.dart';
import '../theme/app_theme.dart';

/// The weekly muggu (రంగోలి) grid from BRANDING.md sec 7: the rangoli
/// drawn on the threshold at dawn, gone by evening -- already a daily
/// ritual with a visible artefact, which is exactly the shape of a
/// streak mechanic. A completed day draws one more loop; a missed day
/// leaves the pattern unfinished rather than destroying it; the week
/// resets each Monday rather than one long number that can be lost.
///
/// This is a programmatic placeholder motif, not the real illustration
/// BRANDING sec 7 eventually wants -- see CLAUDE.md's Phase D
/// follow-up log. [_MugguLoopPainter] draws a simple four-petal knot
/// per day rather than authored kalamkari artwork, but the states it
/// renders (unfinished / complete / today-in-progress / not-yet) are
/// the real mechanic, so swapping in real art later only touches this
/// one file.
class WeeklyMuggu extends StatelessWidget {
  final List<MugguDay> days;

  const WeeklyMuggu({super.key, required this.days});

  static const _dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final completedCount = days.where((d) => d.state == MugguDayState.complete).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('This week', style: theme.textTheme.titleLarge),
                Text(
                  '$completedCount / 7 days',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final day = days[i];
                return Column(
                  children: [
                    _MugguDot(day: day, ctaColor: theme.colorScheme.primary, pacha: semantic.pacha),
                    const SizedBox(height: 6),
                    Text(
                      _dayLetters[i],
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: day.state == MugguDayState.today ? FontWeight.w800 : FontWeight.w400,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _MugguDot extends StatelessWidget {
  final MugguDay day;
  final Color ctaColor;
  final Color pacha;

  const _MugguDot({required this.day, required this.ctaColor, required this.pacha});

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final size = day.state == MugguDayState.today ? 38.0 : 34.0;

    Color color;
    double strength;
    switch (day.state) {
      case MugguDayState.complete:
        color = pacha;
        strength = 1.0;
      case MugguDayState.today:
        color = ctaColor;
        strength = 0.25 + day.progress * 0.75;
      case MugguDayState.incomplete:
        color = ink;
        strength = 0.18;
      case MugguDayState.future:
        color = ink;
        strength = 0.08;
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: strength),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, animatedStrength, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _MugguLoopPainter(color: color, strength: animatedStrength, filled: day.state == MugguDayState.complete),
        ),
      ),
    );
  }
}

/// Draws one small four-petal knot -- a simplified single motif from a
/// kambi-muggu line pattern, not an authentic rangoli algorithm. Good
/// enough to carry the "loop drawn each day" idea without pretending to
/// be finished art.
class _MugguLoopPainter extends CustomPainter {
  final Color color;
  final double strength; // 0..1, drives opacity/fill
  final bool filled;

  const _MugguLoopPainter({required this.color, required this.strength, required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final paint = Paint()
      ..color = color.withValues(alpha: strength.clamp(0.08, 1.0))
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Four overlapping petal loops around the center, like a single
    // repeating unit of a dot-grid kolam.
    for (var i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final petalCenter = center + Offset(math.cos(angle), math.sin(angle)) * (r * 0.42);
      final path = Path()
        ..addOval(Rect.fromCenter(center: petalCenter, width: r * 0.85, height: r * 0.5));
      canvas.save();
      canvas.translate(petalCenter.dx, petalCenter.dy);
      canvas.rotate(angle);
      canvas.translate(-petalCenter.dx, -petalCenter.dy);
      canvas.drawPath(path, paint);
      canvas.restore();
    }

    if (!filled) {
      canvas.drawCircle(center, r * 0.14, Paint()..color = color.withValues(alpha: (strength * 1.4).clamp(0.08, 1.0)));
    } else {
      canvas.drawCircle(center, r * 0.16, Paint()..color = color.withValues(alpha: 1.0));
    }
  }

  @override
  bool shouldRepaint(covariant _MugguLoopPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strength != strength || oldDelegate.filled != filled;
}
