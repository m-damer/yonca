import 'package:flutter/material.dart';

import '../../shared/ds.dart';

import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

/// A settings sub-page: header band with a back button and a scrolling body.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({super.key, required this.title, required this.children, this.actions = const []});
  final String title;

  /// Buttons at the right end of the header.
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, 0),
            child: SafeArea(
              bottom: false,
              child: Row(children: [
                GlassIconButton(icon: Lu.chevronLeft, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: AppSpace.md),
                Expanded(child: PageTitle(title)),
                for (var i = 0; i < actions.length; i++) ...[const SizedBox(width: AppSpace.sm), actions[i]],
              ]),
            ),
          ),
          Expanded(child: LabelInset(inset: 0, child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.x5), children: children))),
        ]),
      ),
    );
  }
}

/// Rows grouped in one card with dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, indent: AppSpace.lg, endIndent: AppSpace.lg, color: p.separator),
            children[i],
          ],
        ]),
      ),
    );
  }
}

/// A row with a title, an optional second line and a trailing widget.
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.title, this.subtitle, this.value, this.trailing, this.onTap, this.chevron = false, this.icon, this.leadingWidget, this.titleFamily, this.subtitleFamily, this.vpad, this.titleWeight = FontWeight.w500});
  final String title;
  final String? subtitle;
  final String? value;
  final double? vpad;
  final FontWeight titleWeight;
  final Widget? leadingWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final IconData? icon;
  final String? titleFamily;
  final String? subtitleFamily;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: vpad ?? AppSpace.md),
        child: Row(children: [
          if (leadingWidget != null) ...[leadingWidget!, const SizedBox(width: AppSpace.md)],
          if (icon != null) ...[
            Container(
              width: AppControl.sm,
              height: AppControl.sm,
              decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: Icon(icon, size: AppIcon.md, color: p.onPrimaryContainer),
            ),
            const SizedBox(width: AppSpace.md),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, fontWeight: titleWeight, fontFamily: titleFamily)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2, fontFamily: subtitleFamily)),
            ]),
          ),
          if (value != null) Padding(padding: const EdgeInsetsDirectional.only(start: AppSpace.sm), child: Text(value!, style: TextStyle(fontSize: AppFont.label, color: p.text2))),
          if (trailing != null) Padding(padding: const EdgeInsetsDirectional.only(start: AppSpace.sm), child: trailing),
          if (chevron) Padding(padding: const EdgeInsetsDirectional.only(start: AppSpace.sm), child: Icon(Lu.chevronRight, size: AppIcon.lg, color: p.text)),
        ]),
      ),
    );
  }
}

/// A row whose trailing control is a filled check circle when chosen, an empty ring otherwise.
class SettingsChoice extends StatelessWidget {
  const SettingsChoice({super.key, required this.title, this.subtitle, required this.selected, required this.onTap, this.titleFamily, this.subtitleFamily});
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final String? titleFamily;
  final String? subtitleFamily;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SettingsRow(
      title: title,
      subtitle: subtitle,
      titleFamily: titleFamily,
      subtitleFamily: subtitleFamily,
      onTap: onTap,
      trailing: selected
          ? Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
              child: Icon(Lu.check, size: AppIcon.sm, color: p.onPrimary),
            )
          : Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.radioOff, width: 2))),
    );
  }
}

class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({super.key, required this.title, this.subtitle, required this.value, required this.onChanged, this.vpad});
  final double? vpad;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) =>
      SettingsRow(vpad: vpad, title: title, subtitle: subtitle, onTap: () => onChanged(!value), trailing: AppSwitch(value: value, onChanged: onChanged));
}


/// The switch: 48x28 track (surface2 with a 1px line off, accent on) with a 24px knob.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final off = p.switchOff;
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: AppControl.lg,
          height: AppSpace.x3,
          padding: const EdgeInsets.all(AppSpace.xxs),
          alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          decoration: BoxDecoration(color: value ? p.primary : off, borderRadius: BorderRadius.circular(AppRadius.pill), border: value ? null : Border.all(color: p.glassBorder)),
          child: Container(width: AppSpace.xxl, height: AppSpace.xxl, decoration: BoxDecoration(color: p.knob, shape: BoxShape.circle)),
        ),
      ),
    );
  }
}


/// The canvas segmented control: grey 46 high track, 3px inset, white pill on the chosen label.
class SegControl extends StatelessWidget {
  const SegControl({super.key, required this.labels, required this.selected, required this.onSelect, this.pillHeight = 40, this.weights});
  final double pillHeight;

  /// Relative widths of the pills; equal when null.
  final List<int>? weights;
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpace.xs),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            flex: weights?[i] ?? 1,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(i),
              child: Container(
                height: pillHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == selected ? p.segmentOn : null,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: i == selected ? Border.all(color: p.glassBorder) : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
                  child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.meta, fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500, color: i == selected ? p.text : p.text2)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
