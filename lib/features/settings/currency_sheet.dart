import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../domain/deal_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';

/// Add custom currency (design G8): code, symbol, name, decimals and where the symbol goes.
Future<void> showCurrencySheet(BuildContext context, AppController c) {
  final l = AppLocalizations.of(context);
  final code = TextEditingController();
  final symbol = TextEditingController();
  final name = TextEditingController();
  var decimals = 2;
  var after = true;
  String? error;
  return showGlassSheet<void>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) {
        Future<void> pickDecimals() async {
          final v = await showGlassSheet<int>(
            ctx,
            builder: (c2) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SheetTitle(l.curDecimals),
              for (final (i, n) in [0, 2, 3].indexed) SheetItem(first: i == 0, title: '$n', bold: n == decimals, selected: n == decimals, onTap: () => Navigator.of(c2).pop(n)),
            ]),
          );
          if (v != null) setS(() => decimals = v);
        }

        Future<void> pickPos() async {
          final v = await showGlassSheet<bool>(
            ctx,
            builder: (c2) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SheetTitle(l.curSymbolPos),
              SheetItem(first: true, title: l.curBefore, bold: !after, selected: !after, onTap: () => Navigator.of(c2).pop(false)),
              SheetItem(title: l.curAfter, bold: after, selected: after, onTap: () => Navigator.of(c2).pop(true)),
            ]),
          );
          if (v != null) setS(() => after = v);
        }

        Future<void> save() async {
          final k = code.text.trim().toUpperCase();
          if (!RegExp(r'^[A-Z]{3}$').hasMatch(k)) {
            setS(() => error = l.curCodeInvalid);
            return;
          }
          final ok = await c.addCustomCurrency(CurrencyDef(
            code: k,
            symbol: symbol.text.trim().isEmpty ? k : symbol.text.trim(),
            name: name.text.trim().isEmpty ? k : name.text.trim(),
            decimals: decimals,
            symbolAfter: after,
          ));
          if (!ok) {
            setS(() => error = l.curExists);
            return;
          }
          if (ctx.mounted) Navigator.of(ctx).pop();
        }

        return SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SheetTitle(l.addCustomCurrency),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: GlassField(
                  controller: code,
                  label: l.curCode,
                  autofocus: true,
                  maxLength: 3,
                  textCapitalization: TextCapitalization.characters,
                  forceLtr: true,
                  error: error,
                  onChanged: (_) => setS(() => error = null),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: GlassField(controller: symbol, label: l.curSymbol, maxLength: 4)),
            ]),
            const SizedBox(height: 12),
            GlassField(controller: name, label: l.curName, maxLength: 30),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: GlassSelectField(label: l.curDecimals, value: '$decimals', onTap: pickDecimals)),
              const SizedBox(width: 10),
              Expanded(child: GlassSelectField(label: l.curSymbolPos, value: after ? l.curAfter : l.curBefore, onTap: pickPos)),
            ]),
            const SizedBox(height: 16),
            SheetButtons(secondary: l.cancel, onSecondary: () => Navigator.of(ctx).pop(), primary: l.save, onPrimary: save),
          ]),
        );
      },
    ),
  );
}
