import 'package:flutter/material.dart';

import '../../core/text_normalize.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';

class _Country {
  const _Country(this.en, this.ar, this.code, this.flag);
  final String en;
  final String ar;
  final String code;
  final String flag;
}

const _countries = [
  _Country('Syria', 'سوريا', '+963', '🇸🇾'),
  _Country('Lebanon', 'لبنان', '+961', '🇱🇧'),
  _Country('Jordan', 'الأردن', '+962', '🇯🇴'),
  _Country('Türkiye', 'تركيا', '+90', '🇹🇷'),
  _Country('Iraq', 'العراق', '+964', '🇮🇶'),
  _Country('Saudi Arabia', 'السعودية', '+966', '🇸🇦'),
  _Country('Egypt', 'مصر', '+20', '🇪🇬'),
  _Country('United Arab Emirates', 'الإمارات', '+971', '🇦🇪'),
  _Country('Kuwait', 'الكويت', '+965', '🇰🇼'),
  _Country('Qatar', 'قطر', '+974', '🇶🇦'),
  _Country('Oman', 'عُمان', '+968', '🇴🇲'),
  _Country('Bahrain', 'البحرين', '+973', '🇧🇭'),
  _Country('Germany', 'ألمانيا', '+49', '🇩🇪'),
  _Country('United Kingdom', 'المملكة المتحدة', '+44', '🇬🇧'),
  _Country('United States', 'الولايات المتحدة', '+1', '🇺🇸'),
];

/// The flag for a dial code, or a globe when the code is not in the list.
String flagFor(String code) {
  for (final c in _countries) {
    if (c.code == code) return c.flag;
  }
  return '\u{1F310}';
}

/// Flag and a small arrow: the country selector shown inside phone fields.
class CountrySelector extends StatelessWidget {
  const CountrySelector({super.key, required this.code, required this.onTap});
  final String code;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(flagFor(code), style: const TextStyle(fontSize: 24, height: 1)),
        const SizedBox(width: 10),
        Icon(Icons.keyboard_arrow_down, size: 20, color: context.palette.text2),
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
        final list = _countries.where((c) => q.isEmpty || normalizeText(c.en).contains(q) || normalizeText(c.ar).contains(q) || c.code.contains(q)).toList();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(l.countryTitle),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: p.glass,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.glassBorder),
              ),
              child: Row(children: [
                Icon(Icons.search, color: p.text2),
                const SizedBox(width: 10),
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
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 6 * 48),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < list.length; i++)
                    SheetItem(
                      first: i == 0,
                      vpad: 11.5,
                      title: arabic ? list[i].ar : list[i].en,
                      bold: list[i].code == current,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(list[i].code, textDirection: TextDirection.ltr, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: p.text2)),
                        if (list[i].code == current) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.check, color: p.primary, size: 22),
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

/// True when a typed number has too few digits to be a phone number.
bool phoneTooShort(String countryCode, String number) {
  if (number.trim().isEmpty) return false;
  final n = normalizePhone(countryCode, number);
  final cc = normalizePhone('', countryCode).replaceAll('+', '');
  final national = n.startsWith(cc) ? n.length - cc.length : n.length;
  return national < 7;
}
