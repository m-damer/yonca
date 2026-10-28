import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/palette.dart';
import '../theme/glass.dart' show GlassCard;

/// Shared states: empty, loading, error, offline (design: shared states).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 32, color: p.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: p.text)),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body!, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 1.4, color: p.text2)),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Semantics(
        label: l.stateLoading,
        child: const CircularProgressIndicator(),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.error_outline,
      title: l.stateError,
      action: FilledButton(onPressed: onRetry, child: Text(l.stateRetry)),
    );
  }
}

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: p.primaryContainer,
      child: Text(l.stateOffline, style: TextStyle(color: p.onPrimaryContainer)),
    );
  }
}


/// Grey placeholder cards while the Timeline loads: five 68 high cards, 40 square icon and two bars.
class TimelineSkeleton extends StatelessWidget {
  const TimelineSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bar = context.palette.text.withValues(alpha: 0.08);
    Widget box(double w, double h, double r) => Container(width: w, height: h, decoration: BoxDecoration(color: bar, borderRadius: BorderRadius.circular(r)));
    return Semantics(
      label: l.stateLoading,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        children: [
          for (var i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  height: 40,
                  child: Row(children: [
                    box(40, 40, 8),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      box(159.6, 12, 6),
                      const SizedBox(height: 8),
                      box(106.4, 12, 6),
                    ]),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
