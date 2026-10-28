import 'package:flutter/material.dart';

import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';

/// A settings sub-page: header band with a back button and a scrolling body.
class SettingsScaffold extends StatelessWidget {
  const SettingsScaffold({super.key, required this.title, required this.children, this.actions = const []});
  final String title;

  /// Buttons at the right end of the header.
  final List<Widget> actions;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: SafeArea(
              bottom: false,
              child: Row(children: [
                GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: p.onHeader))),
                ...actions,
              ]),
            ),
          ),
          Expanded(child: LabelInset(inset: 0, child: ListView(padding: const EdgeInsets.fromLTRB(20, 10, 20, 40), children: children))),
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
            if (i > 0) Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: p.separator),
            children[i],
          ],
        ]),
      ),
    );
  }
}

/// A row with a title, an optional second line and a trailing widget.
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.title, this.subtitle, this.value, this.trailing, this.onTap, this.chevron = false, this.icon, this.leadingWidget, this.titleFamily, this.subtitleFamily, this.vpad});
  final String title;
  final String? subtitle;
  final String? value;
  final double? vpad;
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
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: vpad ?? 10.5),
        child: Row(children: [
          if (leadingWidget != null) ...[leadingWidget!, const SizedBox(width: 12)],
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 20, color: p.primary),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w500, fontFamily: titleFamily)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 13, height: 18.2 / 13, color: p.text2, fontFamily: subtitleFamily)),
            ]),
          ),
          if (value != null) Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: Text(value!, style: TextStyle(fontSize: 14, color: p.text2))),
          if (trailing != null) Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: trailing),
          if (chevron) Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: Icon(Icons.chevron_right, size: 22, color: p.text)),
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
              child: Icon(Icons.check, size: 16, color: p.onPrimary),
            )
          : Container(width: 24, height: 24, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF48484A) : const Color(0xFFC7C7CC), width: 2))),
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


/// The canvas switch: 50x30 track (grey off, accent on) with a 24px white knob.
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final off = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF48484A) : const Color(0xFFD1D1D6);
    return Semantics(
      toggled: value,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 50,
          height: 30,
          padding: const EdgeInsets.all(3),
          alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          decoration: BoxDecoration(color: value ? p.primary : off, borderRadius: BorderRadius.circular(15)),
          child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        ),
      ),
    );
  }
}


/// The canvas segmented control: grey 46 high track, 3px inset, white pill on the chosen label.
class SegControl extends StatelessWidget {
  const SegControl({super.key, required this.labels, required this.selected, required this.onSelect});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(i),
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: i == selected ? (dark ? const Color(0xFF48484A) : p.glass) : null,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: i == selected ? const [BoxShadow(color: Color(0x1F000000), blurRadius: 2, offset: Offset(0, 1))] : null,
                ),
                child: Text(labels[i], style: TextStyle(fontSize: 13, fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500, color: i == selected ? p.text : p.text2)),
              ),
            ),
          ),
      ]),
    );
  }
}
