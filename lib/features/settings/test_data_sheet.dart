import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/lucide.dart';
import '../data/backup_sheet.dart';

/// The hidden Test data tool (tap the version on the About page seven times): adds thousands of made-up
/// contacts to check how long lists behave, and removes them again. Real contacts are never touched.
Future<void> showTestDataSheet(BuildContext context, AppController controller) async {
  final repo = controller.contacts;
  if (repo == null) return;
  final l = AppLocalizations.of(context);
  final choice = await showSheetDialog<String>(
    context: context,
    builder: (ctx) => SheetDialog(
      title: Text(l.testDataTitle),
      content: Text(l.testDataBody),
      actions: [
        DialogConfirm(l.testDataAdd, onPressed: () => Navigator.of(ctx).pop('add')),
        DialogConfirm(l.testDataRemove, danger: true, onPressed: () => Navigator.of(ctx).pop('remove')),
        DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop()),
      ],
    ),
  );
  if (!context.mounted || choice == null) return;
  if (choice == 'add') {
    await showGlassSheet<void>(
      context,
      builder: (ctx) => BackupProgressSheet(
        title: l.testDataAdding,
        readyTitle: l.testDataAdded,
        showFile: false,
        icon: Lu.users,
        run: (progress) async {
          await repo.addTestContacts(3000, onProgress: progress);
          return const BackupInfo(name: '', bytes: 0);
        },
      ),
      dismissible: false,
    );
  } else {
    await repo.removeTestContacts();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.testDataRemoved)));
  }
}
