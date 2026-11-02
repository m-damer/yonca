import 'package:flutter/material.dart';

import '../theme/glass.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'glass_widgets.dart';

/// Shared building blocks of the design system. Change one here and every screen that uses it follows.

/// Title in the top bar.
class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: AppFont.pageTitle, fontWeight: FontWeight.w600, color: context.palette.onHeader),
      );
}

/// Top bar of a page: back (or close) button, title, and optional buttons at the end.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.close = false, this.onBack, this.actions = const []});
  final String title;

  /// Show a close (x) button instead of a back chevron.
  final bool close;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => HeaderBand(
        padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, 0),
        child: Row(children: [
          GlassIconButton(icon: close ? Icons.close : Icons.chevron_left, onHeader: true, onTap: onBack ?? () => Navigator.of(context).maybePop()),
          const SizedBox(width: AppSpace.md),
          Expanded(child: PageTitle(title)),
          for (var i = 0; i < actions.length; i++) ...[const SizedBox(width: AppSpace.sm), actions[i]],
        ]),
      );
}

/// Six grey dots that mark a row as draggable. Wrap in [DragHandle] inside a reorderable list.
class DragDots extends StatelessWidget {
  const DragDots({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.palette.handle;
    return SizedBox(
      width: 11,
      height: 15,
      child: Wrap(spacing: 3, runSpacing: 3, children: [
        for (var d = 0; d < 6; d++) Container(width: 4, height: 4, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(AppRadius.xxs))),
      ]),
    );
  }
}

/// Drag handle of row [index] in a reorderable list.
class DragHandle extends StatelessWidget {
  const DragHandle({super.key, required this.index});
  final int index;

  @override
  Widget build(BuildContext context) => ReorderableDragStartListener(
        index: index,
        // A finger-sized target: the dots alone are too small to catch.
        child: const SizedBox(width: AppControl.md, height: AppControl.lg, child: Center(child: DragDots())),
      );
}

/// Small grey badge with a number or a short word (stage counts, "In use").
class CountBadge extends StatelessWidget {
  const CountBadge(this.text, {super.key, this.muted = false});
  final String text;

  /// Secondary text colour, for words rather than numbers.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 20.8,
      constraints: const BoxConstraints(minWidth: 23.2),
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.xs)),
      child: Text(text, style: TextStyle(fontSize: AppFont.badge, fontWeight: FontWeight.w600, color: muted ? p.text2 : p.text)),
    );
  }
}

/// Blue text button for quiet actions ("Restore default stages", "Hidden pairs").
class LinkButton extends StatelessWidget {
  const LinkButton(this.label, {super.key, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(minimumSize: const Size(0, 44), foregroundColor: context.palette.primary),
        child: Text(label, style: const TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w500)),
      );
}

/// One entry of a [HeaderMenu].
class MenuAction<T> {
  const MenuAction(this.value, this.icon, this.label, {this.danger = false});
  final T value;
  final IconData icon;
  final String label;
  final bool danger;
}

/// The ⋮ button of a page header with a dropdown list. Every page uses this one menu
/// so the list looks and behaves the same everywhere.
class HeaderMenu<T> extends StatelessWidget {
  const HeaderMenu({super.key, required this.actions, required this.onSelected});
  final List<MenuAction<T>> actions;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopupMenuButton<T>(
      color: p.sheet,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final a in actions)
          PopupMenuItem<T>(
            value: a.value,
            height: AppControl.lg,
            child: Row(children: [
              Icon(a.icon, color: a.danger ? p.error : p.primary, size: AppIcon.lg),
              const SizedBox(width: AppSpace.lg),
              Text(a.label, style: TextStyle(fontSize: AppFont.label, color: a.danger ? p.error : null)),
            ]),
          ),
      ],
      child: const IgnorePointer(child: GlassIconButton(icon: Icons.more_vert, onTap: null, onHeader: true)),
    );
  }
}
