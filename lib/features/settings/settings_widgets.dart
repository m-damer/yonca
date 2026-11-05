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
            if (i > 0) Divider(height: AppStroke.hairline, thickness: AppStroke.hairline, indent: AppSpace.lg, endIndent: AppSpace.lg, color: p.separator),
            children[i],
          ],
        ]),
      ),
    );
  }
}

/// A row with a title, an optional second line and a trailing widget.
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.title, this.subtitle, this.value, this.trailing, this.onTap, this.chevron = false, this.icon, this.leadingWidget, this.titleFamily, this.subtitleFamily, this.vpad, this.titleWeight = AppWeight.medium, this.ltrTitle = false});

  /// Read the title left to right even in Arabic (a phone number, an email, a web address).
  final bool ltrTitle;
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
            IconTile(icon: icon, color: p.onPrimaryContainer),
            const SizedBox(width: AppSpace.md),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, textDirection: ltrTitle ? TextDirection.ltr : null, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, fontWeight: titleWeight, fontFamily: titleFamily)),
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
              width: AppSize.s24,
              height: AppSize.s24,
              decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
              child: Icon(Lu.check, size: AppIcon.sm, color: p.onPrimary),
            )
          : Container(width: AppSize.s24, height: AppSize.s24, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.radioOff, width: AppStroke.regular))),
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
          duration: AppMotion.fast,
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
                  child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.meta, fontWeight: i == selected ? AppWeight.semibold : AppWeight.medium, color: i == selected ? p.text : p.text2)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}


/// Segmented control that scrolls sideways when the labels do not fit (five contact tabs in Arabic).
/// Looks like [SegControl]; the chosen segment is kept in view, also when the page is swiped.
class ScrollSegControl extends StatefulWidget {
  const ScrollSegControl({super.key, required this.labels, required this.selected, required this.onSelect, this.pillHeight = AppControl.lg - AppSpace.sm});
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  final double pillHeight;

  @override
  State<ScrollSegControl> createState() => _ScrollSegControlState();
}

class _ScrollSegControlState extends State<ScrollSegControl> {
  late final List<GlobalKey> _keys = List.generate(widget.labels.length, (_) => GlobalKey());
  final _ctl = ScrollController();

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(covariant ScrollSegControl old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _reveal();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.selected >= _keys.length) return;
      final ro = _keys[widget.selected].currentContext?.findRenderObject();
      if (ro == null || !_ctl.hasClients) return;
      // Only the track scrolls; the page itself stays where it is.
      _ctl.position.ensureVisible(ro, alignment: .5, duration: AppMotion.normal, curve: AppMotion.curve);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      // The tabs slide under the rounded corners instead of showing a flat cut edge over them.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: SingleChildScrollView(
        controller: _ctl,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(AppSpace.xs),
        child: Row(children: [
          for (var i = 0; i < widget.labels.length; i++)
            GestureDetector(
              key: _keys[i],
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onSelect(i),
              child: Container(
                height: widget.pillHeight,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
                decoration: BoxDecoration(
                  color: i == widget.selected ? p.segmentOn : null,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: i == widget.selected ? Border.all(color: p.glassBorder) : null,
                ),
                child: Text(widget.labels[i], maxLines: 1, style: TextStyle(fontSize: AppFont.meta, fontWeight: i == widget.selected ? AppWeight.semibold : AppWeight.medium, color: i == widget.selected ? p.text : p.text2)),
              ),
            ),
        ]),
      ),
    );
  }
}
