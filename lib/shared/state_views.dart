import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/glass.dart';
import '../theme/palette.dart';

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
        child: GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: p.primary),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              if (body != null) ...[
                const SizedBox(height: 8),
                Text(body!, textAlign: TextAlign.center, style: TextStyle(color: p.text2)),
              ],
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
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
