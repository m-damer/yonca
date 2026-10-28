import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/palette.dart';

/// Square icon button: 44x44, radius 8, surface fill.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 44,
    this.radius = 8,
    this.filled = false,
    this.onHeader = false,
  });
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final double radius;
  final bool filled;
  final bool onHeader;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = BorderRadius.circular(radius);
    final bg = filled ? p.primary : (onHeader ? p.headerSoft : p.glass);
    final fg = filled ? p.onPrimary : (onHeader ? p.onHeader : p.text);
    final child = Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: r),
      child: InkWell(
        onTap: onTap,
        borderRadius: r,
        child: SizedBox(width: size, height: size, child: Icon(icon, size: 22, color: fg)),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

/// Filter chip: radius 6, grey when off, blue fill when selected.
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
    final fg = selected ? p.onPrimary : p.text;
    return Material(
      color: selected ? p.primary : p.surface2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: InkWell(
        onTap: onTap,
        customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: stretch ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              if (selected && check) ...[Icon(Icons.check, size: dense ? 16 : 18, color: fg), SizedBox(width: dense ? 4 : 6)],
              if (dotColor != null) ...[
                Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
              ],
              if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
              if (stretch)
                Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: fg, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)))
              else
                Text(label, style: TextStyle(fontSize: 13, color: fg, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
              if (onRemove != null) ...[
                const SizedBox(width: 8),
                GestureDetector(onTap: onRemove, child: Icon(Icons.close, size: 18, color: fg)),
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
        if (i > 0) const SizedBox(width: 8),
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
      padding: EdgeInsets.symmetric(horizontal: large ? 10 : 8, vertical: large ? 4.6 : 2),
      decoration: BoxDecoration(color: back, borderRadius: BorderRadius.circular(4)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: large ? 16 : 15, color: front), SizedBox(width: large ? 5 : 5)],
        Text(text, style: TextStyle(color: front, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Group label above a list of settings: 15/600 muted.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(4, 16, 4, 8)});
  final String text;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: padding,
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w600, color: p.text2)),
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
  });
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
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(widget.label, style: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500, color: p.text2)),
        ),
        Container(
          constraints: BoxConstraints(minHeight: multi ? 88 : 46),
          padding: EdgeInsets.symmetric(horizontal: focused ? 13 : 14, vertical: multi ? 11 : 0),
          decoration: BoxDecoration(
            color: p.glass,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: focused ? 2 : 1),
          ),
          child: Directionality(
            textDirection: widget.forceLtr ? TextDirection.ltr : Directionality.of(context),
            child: Row(
            crossAxisAlignment: multi ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 10)],
              Expanded(
                child: Row(children: [
                  if (widget.prefixText != null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: Text(widget.prefixText!,
                          textDirection: TextDirection.ltr, style: TextStyle(fontSize: 16, height: 1.5, color: p.text)),
                    ),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      autofocus: widget.autofocus,
                      keyboardType: widget.keyboardType,
                      maxLines: widget.maxLines,
                      minLines: 1,
                      textDirection: widget.textDirection,
                      textCapitalization: widget.textCapitalization,
                      textInputAction: widget.textInputAction,
                      onChanged: widget.onChanged,
                      inputFormatters: widget.maxLength == null ? null : [LengthLimitingTextInputFormatter(widget.maxLength)],
                      style: TextStyle(fontSize: 16, height: 1.5, color: p.text),
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
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: p.error),
                const SizedBox(width: 6),
                Expanded(child: Text(widget.error!, style: TextStyle(fontSize: 12.5, color: p.error))),
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
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label, style: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500, color: p.text2)),
      ),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: p.glass,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: error ? p.error : p.glassBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(value, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 16, color: p.text)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 20, color: p.text2),
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
}) {
  final p = context.palette;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollControlled,
    useSafeArea: true,
    backgroundColor: p.sheet,
    barrierColor: p.scrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: p.glassBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Flexible(child: builder(ctx)),
          ],
        ),
      ),
    ),
  );
}

/// Buttons: 48 high, radius 8. Filled = blue; [outlined] = grey secondary; [danger] = grey with red text.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onPressed, this.outlined = false, this.height = 48, this.accent = false, this.danger = false, this.icon, this.fontSize = 15});
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
    final r = BorderRadius.circular(8);
    final line = danger ? p.error : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF636366) : const Color(0xFFC7C7CC));
    return Material(
      color: secondary ? Colors.transparent : (accent ? p.accent : p.primary),
      shape: RoundedRectangleBorder(borderRadius: r, side: secondary ? BorderSide(color: line) : BorderSide.none),
      child: InkWell(
        onTap: onPressed,
        borderRadius: r,
        child: Container(
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
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
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label, style: TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w500, color: p.text2)),
      ),
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: p.glass,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: p.glassBorder),
          ),
          child: Row(children: [
            Expanded(child: Text(value, style: TextStyle(fontSize: 16, color: p.text))),
            trailing ?? Icon(Icons.arrow_drop_down, color: p.text2),
          ]),
        ),
      ),
    ]);
  }
}

/// Search field: 42 high, radius 8, surface fill.
class SearchPill extends StatefulWidget {
  const SearchPill({super.key, required this.controller, required this.hint, this.onChanged, this.autofocus = false, this.border = true, this.height = 46});
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
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: p.glass, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(Icons.search, size: 22, color: p.text2),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: widget.controller,
            autofocus: widget.autofocus,
            onChanged: widget.onChanged,
            style: TextStyle(fontSize: 15, color: p.text),
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
            child: Icon(Icons.close, color: p.text2),
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
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: p.glassBorder))),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: p.primary),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.text))),
        ]),
      ),
    );
  }
}
