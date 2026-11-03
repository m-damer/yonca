import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/lucide.dart';

/// Square icon button: 44x44, radius 16, surface fill with a 1px line.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = AppControl.md,
    this.radius = AppRadius.md,
    this.filled = false,
    this.onHeader = false,
    this.danger = false,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double radius;
  final bool filled;
  final bool onHeader;

  /// Delete and other destructive actions are drawn in the warning colour.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = BorderRadius.circular(radius);
    final bg = filled ? p.primary : (onHeader ? p.headerSoft : p.glass);
    final fg = danger ? p.error : (filled ? p.onPrimary : (onHeader ? p.onHeader : p.text));
    final child = Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: r, side: filled ? BorderSide.none : BorderSide(color: p.glassBorder)),
      child: InkWell(
        onTap: onTap,
        borderRadius: r,
        child: SizedBox(width: size, height: size, child: Icon(icon, size: AppIcon.lg, color: fg)),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

/// Square holder for an icon: equal width and height, the icon exactly in the middle, the same
/// corner radius as the buttons. Use it for every icon that sits in a box.
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.size = AppControl.tile, this.iconSize = AppIcon.md, this.background, this.color, this.child});
  final IconData? icon;
  final double size;
  final double iconSize;
  final Color? background;
  final Color? color;

  /// Replaces the icon (a flag).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background ?? p.surface2, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: child ?? Icon(icon, size: iconSize, color: color ?? p.primary),
    );
  }
}

/// Filter pill: pill shape, grey when off, accent fill when selected.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.onTap,
    this.onRemove,
    this.check = false,
    this.dotColor,
    this.dense = false,
    this.stretch = false,
  });
  final String label;

  /// Fill the width given by the parent (used inside [ChipRow] so chips share a row equally).
  final bool stretch;

  /// Smaller chip for filter rows (design 32 high).
  final bool dense;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final bool check;
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = selected ? p.onPrimary : p.text2;
    return Material(
      color: selected ? p.primary : p.surface2,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          height: AppControl.chip,
          padding: EdgeInsets.symmetric(horizontal: stretch ? AppSpace.sm : AppSpace.lg),
          child: Row(
            mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: stretch ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              if (selected && check) ...[Icon(Lu.check, size: dense ? AppIcon.sm : AppIcon.md, color: fg), SizedBox(width: dense ? AppSpace.xs : AppSpace.sm)],
              if (dotColor != null) ...[
                Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                const SizedBox(width: AppSpace.sm),
              ],
              if (icon != null) ...[Icon(icon, size: AppIcon.md, color: fg), const SizedBox(width: AppSpace.sm)],
              // A long label (a tag, a company) is cut with … instead of overflowing the row.
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.meta, color: fg, fontWeight: selected ? FontWeight.w600 : FontWeight.w500))),
              if (onRemove != null) ...[
                const SizedBox(width: AppSpace.sm),
                GestureDetector(onTap: onRemove, child: Icon(Lu.x, size: AppIcon.md, color: fg)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of chips that share the full width equally (roles, rating).
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.chips});
  final List<PillChip> chips;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (var i = 0; i < chips.length; i++) ...[
        if (i > 0) const SizedBox(width: AppSpace.sm),
        Expanded(
          child: PillChip(
            key: chips[i].key,
            label: chips[i].label,
            selected: chips[i].selected,
            icon: chips[i].icon,
            onTap: chips[i].onTap,
            check: chips[i].check,
            dense: chips[i].dense,
            stretch: true,
          ),
        ),
      ],
    ]);
  }
}

/// Small role badge (design `.tag`).
class TagPill extends StatelessWidget {
  const TagPill(this.text, {super.key, this.icon, this.large = false, this.bg, this.fg});
  final String text;
  final IconData? icon;
  final bool large;

  /// Colours for a status tag (hot, warm, cold, won); other tags are neutral.
  final Color? bg;
  final Color? fg;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final back = bg ?? p.surface2;
    final front = fg ?? p.text;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? AppSpace.md : AppSpace.sm, vertical: large ? AppSpace.xs : AppSpace.xxs),
      decoration: BoxDecoration(color: back, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: AppIcon.sm, color: front), const SizedBox(width: AppSpace.xs)],
        Text(text, style: TextStyle(color: front, fontSize: AppFont.badge, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Side inset for [SectionLabel]s below: 4 on pages whose cards sit 16 from the edge, 0 where they sit 20.
class LabelInset extends InheritedWidget {
  const LabelInset({super.key, required this.inset, required super.child});
  final double inset;
  static double of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LabelInset>()?.inset ?? 4;
  @override
  bool updateShouldNotify(LabelInset old) => inset != old.inset;
}

/// Group label above a list of settings: 15/600 muted.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding});
  final String text;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final inset = LabelInset.of(context);
    return Padding(
      padding: padding ?? EdgeInsets.fromLTRB(inset, AppSpace.lg, inset, AppSpace.sm),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: AppFont.body, height: AppLine.relaxed, fontWeight: FontWeight.w600, color: p.text2)),
    );
  }
}

/// Text field in the design's glass style (`.tf`): label inside, 1.5 border, primary when focused.
class GlassField extends StatefulWidget {
  const GlassField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboardType,
    this.maxLines = 1,
    this.textDirection,
    this.error,
    this.hint,
    this.autofocus = false,
    this.onChanged,
    this.trailing,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction,
    this.focusNode,
    this.leading,
    this.forceLtr = false,
    this.prefixText,
    this.maxLength,
    this.obscure = false,
  });
  final bool obscure;
  final TextEditingController controller;

  /// Longest text allowed (no counter is shown).
  final int? maxLength;
  final String label;
  final FocusNode? focusNode;

  /// Shown at the start of the field, outside the label and text (for example a country selector).
  final Widget? leading;

  /// Lay the inside of the box out left to right even in Arabic (phone numbers); the label keeps the reading side.
  final bool forceLtr;

  /// Fixed text shown before the typed text (for example the dial code).
  final String? prefixText;
  final TextInputType? keyboardType;
  final int maxLines;
  final TextDirection? textDirection;
  final String? error;
  final String? hint;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;
  final TextCapitalization textCapitalization;
  final TextInputAction? textInputAction;

  @override
  State<GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<GlassField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  void _onFocus() => setState(() {});

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hasError = widget.error != null;
    final focused = _focus.hasFocus;
    final border = hasError ? p.error : (focused ? p.primary : p.glassBorder);
    final multi = widget.maxLines != 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.sm),
          child: Text(widget.label, style: TextStyle(fontSize: AppFont.label, height: AppLine.normal, fontWeight: FontWeight.w500, color: p.text2)),
        ),
        Container(
          constraints: BoxConstraints(minHeight: multi ? 88 : 46),
          padding: EdgeInsets.symmetric(horizontal: focused ? AppSpace.md : AppSpace.lg, vertical: multi ? AppSpace.md : 0),
          decoration: BoxDecoration(
            color: p.glass,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border, width: focused ? 2 : 1),
          ),
          child: Directionality(
            textDirection: widget.forceLtr ? TextDirection.ltr : Directionality.of(context),
            child: Row(
            crossAxisAlignment: multi ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              if (widget.leading != null) ...[widget.leading!, const SizedBox(width: AppSpace.md)],
              Expanded(
                child: Row(children: [
                  if (widget.prefixText != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: AppSpace.sm),
                      child: Text(widget.prefixText!,
                          textDirection: TextDirection.ltr, style: TextStyle(fontSize: AppFont.bodyL, height: AppLine.relaxed, color: p.text)),
                    ),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      autofocus: widget.autofocus,
                      keyboardType: widget.keyboardType,
                      obscureText: widget.obscure,
                      maxLines: widget.maxLines,
                      minLines: 1,
                      textDirection: widget.textDirection,
                      textCapitalization: widget.textCapitalization,
                      textInputAction: widget.textInputAction,
                      onChanged: widget.onChanged,
                      inputFormatters: widget.maxLength == null ? null : [LengthLimitingTextInputFormatter(widget.maxLength)],
                      style: TextStyle(fontSize: AppFont.bodyL, height: AppLine.relaxed, color: p.text),
                      cursorColor: p.primary,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: widget.hint,
                        hintStyle: TextStyle(color: hasError ? p.error : p.text2),
                      ),
                    ),
                  ),
                ]),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.sm, AppSpace.sm, AppSpace.sm, 0),
            child: Row(
              children: [
                Icon(Lu.triangleAlert, size: AppIcon.sm, color: p.error),
                const SizedBox(width: AppSpace.sm),
                Expanded(child: Text(widget.error!, style: TextStyle(fontSize: AppFont.meta, color: p.error))),
              ],
            ),
          ),
      ],
    );
  }
}

/// A read-only field-looking box with a label and a value and a chevron (country and label pickers).
class GlassPickerField extends StatelessWidget {
  const GlassPickerField({super.key, required this.label, required this.value, required this.onTap, this.error = false});
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Text(label, style: TextStyle(fontSize: AppFont.label, height: AppLine.normal, fontWeight: FontWeight.w500, color: p.text2)),
      ),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          decoration: BoxDecoration(
            color: p.glass,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: error ? p.error : p.glassBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(value, textDirection: TextDirection.ltr, style: TextStyle(fontSize: AppFont.bodyL, color: p.text)),
            const SizedBox(width: AppSpace.xs),
            Icon(Lu.chevronDown, size: AppIcon.md, color: p.text2),
          ]),
        ),
      ),
    ]);
  }
}

/// Opens a bottom sheet: surface fill, radius 12 on top, small grab handle.
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollControlled = true,
  bool dismissible = true,
}) {
  final p = context.palette;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollControlled,
    isDismissible: dismissible,
    enableDrag: dismissible,
    useSafeArea: true,
    backgroundColor: p.sheet,
    barrierColor: p.scrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 5,
                margin: const EdgeInsets.only(bottom: AppSpace.lg),
                decoration: BoxDecoration(color: sheetLine(context), borderRadius: BorderRadius.circular(AppRadius.xs)),
              ),
            ),
            Flexible(child: builder(ctx)),
          ],
        ),
      ),
    ),
  );
}

/// Buttons: 48 high, radius 16. Filled = accent; [outlined] = grey secondary; [danger] = grey with red text.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onPressed, this.outlined = false, this.height = 48, this.accent = false, this.danger = false, this.icon, this.fontSize = AppFont.body});
  final double fontSize;
  final String label;

  /// Optional icon before the label.
  final IconData? icon;

  /// Red text on the grey fill, for destructive choices such as Mark as lost.
  final bool danger;
  final VoidCallback? onPressed;

  /// Secondary style: grey fill, normal text.
  final bool outlined;
  final double height;

  /// Same blue fill, for the Save button in a top bar.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final secondary = outlined || danger;
    final fg = secondary ? (danger ? p.error : p.text) : (accent ? p.onAccent : p.onPrimary);
    final r = BorderRadius.circular(AppRadius.md);
    return Material(
      color: secondary ? p.surface2 : (accent ? p.accent : p.primary),
      shape: RoundedRectangleBorder(borderRadius: r),
      child: InkWell(
        onTap: onPressed,
        borderRadius: r,
        child: Container(
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: AppIcon.md, color: fg),
              const SizedBox(width: AppSpace.sm),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: fg),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Full-width read-only box with a label, the chosen value and a dropdown arrow (the "Label" field
/// that appears under a phone, email or address field while it is being edited).
class GlassSelectField extends StatelessWidget {
  const GlassSelectField({super.key, required this.label, required this.value, required this.onTap, this.trailing});

  /// Replaces the dropdown arrow (for example a lock for a fixed value).
  final Widget? trailing;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Text(label, style: TextStyle(fontSize: AppFont.label, height: AppLine.normal, fontWeight: FontWeight.w500, color: p.text2)),
      ),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          decoration: BoxDecoration(
            color: p.glass,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: p.glassBorder),
          ),
          child: Row(children: [
            Expanded(child: Text(value, style: TextStyle(fontSize: AppFont.bodyL, color: p.text))),
            trailing ?? Icon(Lu.chevronDown, size: AppIcon.lg, color: p.text),
          ]),
        ),
      ),
    ]);
  }
}

/// Search field: 42 high, radius 8, surface fill.
class SearchPill extends StatefulWidget {
  const SearchPill({super.key, required this.controller, required this.hint, this.onChanged, this.autofocus = false, this.border = true, this.height = AppControl.md});
  final double height;
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  /// Hairline border, for use on the page background (not needed on the header band).
  final bool border;

  @override
  State<SearchPill> createState() => _SearchPillState();
}

class _SearchPillState extends State<SearchPill> {
  void _changed() => setState(() {});

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
      decoration: BoxDecoration(color: p.glass, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: p.glassBorder)),
      child: Row(children: [
        Icon(Lu.search, size: AppIcon.md, color: p.text2),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: TextField(
            controller: widget.controller,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            style: TextStyle(fontSize: AppFont.body, color: p.text),
            cursorColor: p.primary,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: widget.hint,
              hintStyle: TextStyle(color: p.text2),
            ),
          ),
        ),
        if (widget.controller.text.isNotEmpty)
          GestureDetector(
            onTap: () {
              widget.controller.clear();
              widget.onChanged?.call('');
            },
            child: Icon(Lu.x, color: p.text2),
          ),
      ]),
    );
  }
}


/// One row of an option sheet (the Contact photo style): a soft rounded tile with a blue icon, the label,
/// and a thin inset line above every row but the first.
class GlassSheetOption extends StatelessWidget {
  const GlassSheetOption({super.key, required this.icon, required this.label, required this.onTap, this.first = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool first;

  @override
  Widget build(BuildContext context) => SheetItem(first: first, icon: icon, title: label, onTap: onTap);
}

/// Two buttons at the bottom of a sheet: a grey one (Clear, Cancel) and the main one.
class SheetButtons extends StatelessWidget {
  const SheetButtons({super.key, required this.secondary, required this.onSecondary, required this.primary, required this.onPrimary, this.secondaryFlex = 145, this.primaryFlex = 203, this.fontSize = 15, this.dangerPrimary = false});
  final int secondaryFlex;
  final int primaryFlex;
  final double fontSize;

  /// Red filled-text style for the primary action (Delete).
  final bool dangerPrimary;
  final String secondary;
  final VoidCallback? onSecondary;
  final String primary;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(flex: secondaryFlex, child: PillButton(label: secondary, outlined: true, fontSize: fontSize, onPressed: onSecondary)),
        const SizedBox(width: AppSpace.md),
        Expanded(flex: primaryFlex, child: PillButton(label: primary, fontSize: fontSize, danger: dangerPrimary, onPressed: onPrimary)),
      ]);
}

/// Sheet heading: 22/600, with an optional [trailing] widget such as Reset.
class SheetTitle extends StatelessWidget {
  const SheetTitle(this.text, {super.key, this.trailing, this.bottom = 8});
  final String text;
  final double bottom;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, bottom),
        child: Row(children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: AppFont.pageTitle, fontWeight: FontWeight.w600, height: AppLine.relaxed))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Small grey heading above the rows of a sheet, such as ADD.
class SheetOverline extends StatelessWidget {
  const SheetOverline(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.sm, 0, AppSpace.sm, AppSpace.sm),
        child: Text(text.toUpperCase(), style: TextStyle(fontSize: AppFont.meta, fontWeight: FontWeight.w600, color: context.palette.text2)),
      );
}

/// One row of a sheet: optional icon box, 17/500 title, optional subtitle, optional round check.
/// [first] leaves out the line above the row.
class SheetItem extends StatelessWidget {
  const SheetItem({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconSize = AppControl.tile,
    this.leading,
    this.onTap,
    this.first = false,
    this.danger = false,
    this.selected,
    this.bold = false,
    this.vpad = 13.5,
    this.trailing,
    this.ltrTitle = false,
  });
  final String title;
  final String? subtitle;
  final bool ltrTitle;
  final IconData? icon;
  final double iconSize;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool first;
  final bool danger;

  /// Shows the round check on the right: filled when true, empty ring when false. Null hides it.
  final bool? selected;
  final bool bold;
  final double vpad;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = danger ? p.error : p.text;
    return Container(
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: p.separator))),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: vpad),
          child: Row(children: [
            if (leading != null || icon != null) ...[
              leading ??
                  IconTile(icon: icon, size: iconSize, background: danger ? p.errorContainer : p.surface2, color: danger ? p.onErrorContainer : p.primary),
              const SizedBox(width: AppSpace.md),
            ],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, textDirection: ltrTitle ? TextDirection.ltr : null, style: TextStyle(fontSize: AppFont.subtitle, fontWeight: bold ? FontWeight.w600 : FontWeight.w500, color: fg)),
                if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: AppFont.meta, color: p.text2, height: AppLine.normal)),
              ]),
            ),
            if (trailing != null) trailing!,
            if (selected != null) SheetRadio(selected: selected!),
          ]),
        ),
      ),
    );
  }
}

/// Round 24px check used on the right of a [SheetItem].
class SheetRadio extends StatelessWidget {
  const SheetRadio({super.key, required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? p.primary : Colors.transparent,
        border: Border.all(color: selected ? p.primary : sheetLine(context), width: 2),
      ),
      child: selected ? Icon(Lu.check, size: AppIcon.sm, color: p.onPrimary) : null,
    );
  }
}

/// Grey used for the sheet handle and empty check rings.
Color sheetLine(BuildContext context) => context.palette.sheetLine;

/// "11/30" shown inside a field that has a character limit.
class CharCount extends StatelessWidget {
  const CharCount(this.controller, this.max, {super.key});
  final TextEditingController controller;
  final int max;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, v, __) => Text('${v.text.characters.length}/$max', style: TextStyle(fontSize: AppFont.meta, color: context.palette.text2)),
      );
}

/// Cancel-style action of a dialog (design dialog): blue text, no fill, 48 high.
class DialogCancel extends StatelessWidget {
  const DialogCancel(this.label, {super.key, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          foregroundColor: context.palette.accent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: AppFont.body, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      );
}

/// Main action of a dialog (design dialog): filled blue, or red when [danger], 48 high.
class DialogConfirm extends StatelessWidget {
  const DialogConfirm(this.label, {super.key, required this.onPressed, this.danger = false});
  final String label;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xxl),
        backgroundColor: danger ? p.error : p.primary,
        foregroundColor: danger ? p.onDanger : p.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: AppFont.body, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }
}
