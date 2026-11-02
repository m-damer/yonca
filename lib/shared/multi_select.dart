import 'package:flutter/material.dart';

import '../core/text_normalize.dart';
import '../l10n/app_localizations.dart';
import '../theme/lucide.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'glass_widgets.dart';

/// One choice in a [showSearchableSelect] list.
class PickOption {
  const PickOption(this.id, this.label);
  final Object id;
  final String label;
}

/// Opens a bottom sheet with a search field and a checklist. Returns the chosen ids, or null on Cancel.
/// With [multi] false, tapping a row returns it at once (tapping the chosen row clears it).
Future<Set<Object>?> showSearchableSelect(
  BuildContext context, {
  required String title,
  required List<PickOption> options,
  required Set<Object> selected,
  bool multi = true,
}) =>
    showGlassSheet<Set<Object>>(
      context,
      builder: (ctx) => _SelectSheet(title: title, options: options, initial: selected, multi: multi),
    );

class _SelectSheet extends StatefulWidget {
  const _SelectSheet({required this.title, required this.options, required this.initial, required this.multi});
  final String title;
  final List<PickOption> options;
  final Set<Object> initial;
  final bool multi;

  @override
  State<_SelectSheet> createState() => _SelectSheetState();
}

class _SelectSheetState extends State<_SelectSheet> {
  final _search = TextEditingController();
  late final Set<Object> _sel = {...widget.initial};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final key = normalizeText(_search.text.trim());
    final visible = [for (final o in widget.options) if (key.isEmpty || normalizeText(o.label).contains(key)) o];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SheetTitle(
          widget.title,
          trailing: widget.multi && _sel.isNotEmpty
              ? InkWell(
                  onTap: () => setState(_sel.clear),
                  child: Text(l.msClear, style: TextStyle(color: p.primary, fontWeight: FontWeight.w600, fontSize: AppFont.body)),
                )
              : null,
        ),
        Container(
          height: AppControl.lg,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          decoration: BoxDecoration(color: p.glass, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: p.glassBorder)),
          child: Row(children: [
            Icon(Lu.search, size: AppIcon.md, color: p.text2),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                cursorColor: p.primary,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintText: l.msSearch,
                  hintStyle: TextStyle(color: p.text2),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: AppSpace.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 6 * AppControl.xl),
          child: visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSpace.xl),
                  child: Center(child: Text(l.msNoMatches, style: TextStyle(fontSize: AppFont.body, color: p.text2))),
                )
              : ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final o in visible)
                      SheetItem(
                        first: true,
                        vpad: AppSpace.md,
                        leading: Container(
                          width: AppIcon.lg,
                          height: AppIcon.lg,
                          decoration: BoxDecoration(
                            color: _sel.contains(o.id) ? p.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(widget.multi ? AppRadius.xs : AppRadius.md),
                            border: Border.all(color: _sel.contains(o.id) ? p.primary : sheetLine(context), width: 2),
                          ),
                          child: _sel.contains(o.id) ? Icon(Lu.check, size: AppIcon.sm, color: p.onPrimary) : null,
                        ),
                        title: o.label,
                        onTap: () {
                          if (!widget.multi) {
                            Navigator.of(context).pop(_sel.contains(o.id) ? <Object>{} : <Object>{o.id});
                            return;
                          }
                          setState(() => _sel.contains(o.id) ? _sel.remove(o.id) : _sel.add(o.id));
                        },
                      ),
                  ],
                ),
        ),
        if (widget.multi) ...[
          const SizedBox(height: AppSpace.lg),
          SheetButtons(
            secondary: l.cancel,
            onSecondary: () => Navigator.of(context).pop(),
            primary: l.done,
            onPrimary: () => Navigator.of(context).pop(_sel),
          ),
        ],
      ],
    );
  }
}

/// A full-width field that looks like a dropdown and opens a sheet when tapped.
class DropdownBox extends StatelessWidget {
  const DropdownBox({super.key, required this.label, required this.text, required this.onTap, this.placeholder = false});
  final String label;
  final String text;
  final VoidCallback onTap;

  /// Shows [text] in the muted colour (nothing chosen yet).
  final bool placeholder;

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
          height: AppControl.lg,
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          decoration: BoxDecoration(color: p.glass, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: p.glassBorder)),
          child: Row(children: [
            Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.body, color: placeholder ? p.text2 : p.text))),
            const SizedBox(width: AppSpace.sm),
            Icon(Lu.chevronDown, size: AppIcon.md, color: p.text2),
          ]),
        ),
      ),
    ]);
  }
}

/// Small removable chips in a single row that scrolls sideways.
class ChipsScrollRow extends StatelessWidget {
  const ChipsScrollRow({super.key, required this.chips});
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: AppControl.chip,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
        itemBuilder: (_, i) => Center(child: chips[i]),
      ),
    );
  }
}
