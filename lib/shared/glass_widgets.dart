import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// Square-ish icon button: 44x44, radius 14. On a header band it is a translucent white square.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.size = 44,
    this.radius = 14,
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
    final side = filled || onHeader ? BorderSide.none : BorderSide(color: p.glassBorder);
    final child = Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: r, side: side),
      child: InkWell(
        onTap: onTap,
        borderRadius: r,
        child: SizedBox(width: size, height: size, child: Icon(icon, size: 22, color: fg)),
      ),
    );
    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

/// Outlined pill (design `.chp`): 38 high, 1.5 outline; filled with a check when selected.
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
  });
  final String label;
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
      color: selected ? p.primary : Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: selected ? p.primary : p.outline, width: 1.5)),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected && check) ...[Icon(Icons.check, size: 18, color: fg), const SizedBox(width: 6)],
              if (dotColor != null) ...[
                Container(width: 10, height: 10, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
              ],
              if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
              Text(label,
                  style: TextStyle(fontSize: 14, color: fg, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
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

/// Small role badge (design `.tag`).
class TagPill extends StatelessWidget {
  const TagPill(this.text, {super.key, this.icon, this.large = false, this.bg, this.fg});
  final String text;
  final IconData? icon;
  final bool large;

  /// Colours for a status tag (hot, warm, cold); the role tag uses the green container.
  final Color? bg;
  final Color? fg;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final back = bg ?? p.primaryContainer;
    final front = fg ?? p.onPrimaryContainer;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 12 : 10, vertical: large ? 5 : 2),
      decoration: BoxDecoration(color: back, borderRadius: BorderRadius.circular(large ? 11 : 9)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 15, color: front), const SizedBox(width: 5)],
        Text(text, style: TextStyle(color: front, fontSize: large ? 13 : 11.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// Uppercase section label (design `.lab`).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding = const EdgeInsets.fromLTRB(4, 20, 4, 8)});
  final String text;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    return Padding(
      padding: padding,
      child: Text(
        arabic ? text : text.toUpperCase(),
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: arabic ? 0 : .6, color: p.text2),
      ),
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
    this.prefixText,
  });
  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;

  /// Shown at the start of the field, outside the label and text (for example a country selector).
  final Widget? leading;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          decoration: BoxDecoration(
            color: focused ? p.sheet : p.glass,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            children: [
              if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 10)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: p.text2)),
                    Row(children: [
                      if (widget.prefixText != null)
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: Text(widget.prefixText!,
                              textDirection: TextDirection.ltr, style: TextStyle(fontSize: 17, height: 1.5, color: p.text)),
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
                      style: TextStyle(fontSize: 17, height: 1.5, color: p.text),
                      cursorColor: p.primary,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        hintText: widget.hint,
                        hintStyle: TextStyle(color: hasError ? p.error : p.text2.withValues(alpha: .75)),
                      ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 10, 12, 12),
        decoration: BoxDecoration(
          color: p.glass,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: error ? p.error : p.glassBorder, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: p.text2)),
                Text(value, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 17, height: 1.5, color: p.text)),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 20, color: p.text),
          ],
        ),
      ),
    );
  }
}

/// Opens a bottom sheet in the design's style (radius 32, grab handle, scrim).
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
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: p.outline, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Flexible(child: builder(ctx)),
          ],
        ),
      ),
    ),
  );
}

/// Filled and outlined pill buttons (design `.bt`): 56 high.
class PillButton extends StatelessWidget {
  const PillButton({super.key, required this.label, required this.onPressed, this.outlined = false, this.height = 56, this.accent = false});
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final double height;

  /// Mint fill with dark text, for use on a header band.
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: outlined ? Colors.transparent : (accent ? p.accent : p.primary),
      shape: StadiumBorder(side: outlined ? BorderSide(color: p.outline, width: 1.5) : BorderSide.none),
      child: InkWell(
        onTap: onPressed,
        customBorder: const StadiumBorder(),
        child: Container(
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: outlined ? p.text : (accent ? p.onAccent : p.onPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width read-only box with a label, the chosen value and a dropdown arrow (the "Label" field
/// that appears under a phone, email or address field while it is being edited).
class GlassSelectField extends StatelessWidget {
  const GlassSelectField({super.key, required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 10, 14, 12),
        decoration: BoxDecoration(
          color: p.glass,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.glassBorder, width: 1.5),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: p.text2)),
              Text(value, style: TextStyle(fontSize: 17, height: 1.5, color: p.text)),
            ]),
          ),
          Icon(Icons.arrow_drop_down, color: p.text2),
        ]),
      ),
    );
  }
}
