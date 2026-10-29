import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/format.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';

/// A deal document as typed in the dialog (not saved yet when [id] is null).
class DocDraft {
  DocDraft({this.id, this.reference = '', this.amount, required this.date, this.path, this.name = ''});
  final int? id;
  final String reference;
  final double? amount;
  final DateTime date;
  final String? path;
  final String name;
}

/// The Add document dialog: reference, amount, date and an optional file. Null when cancelled.
Future<DocDraft?> showDealDocumentDialog(BuildContext context, {required String currency}) async {
  final l = AppLocalizations.of(context);
  final ref = TextEditingController();
  final amount = TextEditingController();
  var date = DateTime.now();
  String? path;
  var name = '';
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Text(l.addDocument),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            GlassField(controller: ref, label: l.fieldReference),
            const SizedBox(height: 12),
            GlassField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              label: '${l.fieldAmount} ($currency)',
            ),
            const SizedBox(height: 4),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.fieldDocDate),
              subtitle: Text(formatDay(ctx, date)),
              onTap: () async {
                final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                if (d != null) setS(() => date = d);
              },
            ),
            TextButton.icon(
              onPressed: () async {
                final res = await FilePicker.platform.pickFiles();
                final f = res?.files.single;
                if (f?.path == null) return;
                final dir = await getApplicationDocumentsDirectory();
                final folder = Directory(p.join(dir.path, 'deal_files'))..createSync(recursive: true);
                final dest = p.join(folder.path, '${DateTime.now().microsecondsSinceEpoch}_${f!.name}');
                await File(f.path!).copy(dest);
                setS(() {
                  path = dest;
                  name = f.name;
                });
              },
              icon: const Icon(Icons.attach_file),
              label: Text(name.isEmpty ? l.addFile : name, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
        actions: [
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.save, onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    ),
  );
  final text = amount.text.trim().replaceAll(',', '');
  final out = ok == true ? DocDraft(reference: ref.text, amount: text.isEmpty ? null : double.tryParse(text), date: date, path: path, name: name) : null;
  ref.dispose();
  amount.dispose();
  return out;
}
