import 'package:flutter/material.dart';

import '../../core/countries.dart';
import '../../core/phone_rules.dart';
import '../../core/text_normalize.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/flag_view.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';

/// The flag for a dial code, or a globe when the code is not in the list.
String flagFor(String code) => countryForCode(code)?.flag ?? '\u{1F310}';

/// Flag and a small arrow: the country selector shown inside phone fields.
class CountrySelector extends StatelessWidget {
  const CountrySelector({super.key, required this.code, required this.onTap});
  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        FlagView.dial(code),
        const SizedBox(width: AppSpace.md),
        Icon(Icons.keyboard_arrow_down, size: AppIcon.md, color: context.palette.text2),
      ]),
    );
  }
}

/// Country code picker (design Cf country sheet). Returns the chosen code such as "+963".
Future<String?> showCountrySheet(BuildContext context, String current) {
  final l = AppLocalizations.of(context);
  final arabic = Localizations.localeOf(context).languageCode == 'ar';
  final search = TextEditingController();
  return showGlassSheet<String>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final p = ctx.palette;
        final q = normalizeText(search.text);
        final list = [
          ...kCountries.where((c) => c.arab),
          ...(kCountries.where((c) => !c.arab).toList()..sort((a, b) => arabic ? a.ar.compareTo(b.ar) : a.en.compareTo(b.en))),
        ].where((c) => q.isEmpty || normalizeText(c.en).contains(q) || normalizeText(c.ar).contains(q) || c.code.contains(q) || c.iso.toLowerCase() == q).toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(l.countryTitle),
            Container(
              height: AppControl.lg,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              decoration: BoxDecoration(
                color: p.glass,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: p.glassBorder),
              ),
              child: Row(children: [
                Icon(Icons.search, color: p.text2),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: TextField(
                    controller: search,
                    onChanged: (_) => setSheet(() {}),
                    cursorColor: p.primary,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: l.countrySearch,
                      hintStyle: TextStyle(color: p.text2),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: AppSpace.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 7 * 48),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < list.length; i++)
                    SheetItem(
                      first: i == 0,
                      vpad: 11.5,
                      leading: FlagView.iso(list[i].iso),
                      title: arabic ? list[i].ar : list[i].en,
                      bold: list[i].code == current,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(list[i].code, textDirection: TextDirection.ltr, style: TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w500, color: p.text2)),
                        if (list[i].code == current) ...[
                          const SizedBox(width: AppSpace.md),
                          Icon(Icons.check, color: p.primary, size: AppIcon.lg),
                        ],
                      ]),
                      onTap: () => Navigator.of(ctx).pop(list[i].code),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  ).whenComplete(search.dispose);
}

/// True when a typed number is not valid for the chosen country (see [phoneInvalid]).
bool phoneTooShort(String countryCode, String number) => phoneInvalid(countryCode, number);
