import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../domain/activity_models.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../activities/activity_labels.dart';
import 'contact_widgets.dart';
import '../../theme/lucide.dart';

/// What the selection bar's Actions sheet offers.
enum BulkAction { share, export, edit, remove, task, activity, meeting, deal, field, whatsapp, email, phoneBook, merge, delete }

Future<BulkAction?> showBulkActionsSheet(BuildContext context, {required int count}) {
  final l = AppLocalizations.of(context);
  final items = [
    (BulkAction.share, Lu.share2, l.bulkShare, false),
    (BulkAction.export, Lu.table2, l.bulkExport, false),
    (BulkAction.edit, Lu.pencil, l.bulkTitle, false),
    (BulkAction.remove, Lu.tag, l.bulkRemove, false),
    (BulkAction.task, Lu.circleCheck, l.bulkAddTask, false),
    (BulkAction.activity, Lu.history, l.bulkLogActivity, false),
    (BulkAction.meeting, Lu.calendarDays, l.bulkAddMeeting, false),
    (BulkAction.deal, Lu.handshake, l.bulkDeal, false),
    (BulkAction.field, Lu.slidersHorizontal, l.bulkFieldSet, false),
    (BulkAction.whatsapp, Lu.messageSquare, l.bulkWhatsApp, false),
    (BulkAction.email, Lu.mail, l.bulkEmail, false),
    (BulkAction.phoneBook, Lu.contact, l.saveToPhoneBook, false),
    (BulkAction.merge, Lu.merge, l.bulkMerge, false),
    (BulkAction.delete, Lu.trash2, l.bulkDelete, true),
  ];
  return showGlassSheet<BulkAction>(
    context,
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SheetTitle(l.bulkActions),
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Text(l.bulkActionsSub(count), style: TextStyle(fontSize: AppFont.body, color: ctx.palette.text2)),
      ),
      Flexible(
        child: ListView(shrinkWrap: true, children: [
          for (var i = 0; i < items.length; i++)
            SheetItem(first: i == 0, icon: items[i].$2, title: items[i].$3, danger: items[i].$4, onTap: () => Navigator.of(ctx).pop(items[i].$1)),
        ]),
      ),
    ]),
  );
}

/// A tag and/or a role to take off the selected contacts.
class BulkRemoveChoice {
  const BulkRemoveChoice({this.tag, this.role});
  final String? tag;
  final Role? role;
}

Future<BulkRemoveChoice?> showBulkRemoveSheet(BuildContext context, {required int count, required List<Tag> tags}) {
  final l = AppLocalizations.of(context);
  String? tag;
  Role? role;
  return showGlassSheet<BulkRemoveChoice>(
    context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final p = ctx.palette;
      return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.bulkRemove),
          Text(l.bulkRemoveSub(count), style: TextStyle(fontSize: AppFont.body, height: AppLine.loose, color: p.text2)),
          if (tags.isNotEmpty) ...[
            SectionLabel(l.fieldTags, padding: const EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.sm)),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in tags) PillChip(label: t.name, selected: tag == t.name, onTap: () => setS(() => tag = tag == t.name ? null : t.name)),
            ]),
          ],
          SectionLabel(l.filterRole, padding: const EdgeInsets.fromLTRB(0, AppSpace.lg, 0, AppSpace.sm)),
          ChipRow(chips: [
            for (final r in Role.values) PillChip(label: roleLabel(l, r), selected: role == r, onTap: () => setS(() => role = role == r ? null : r)),
          ]),
          const SizedBox(height: AppSpace.lg),
          SheetButtons(
            secondary: l.cancel,
            onSecondary: () => Navigator.of(ctx).pop(),
            primary: l.bulkRemoveBtn,
            onPrimary: tag == null && role == null ? null : () => Navigator.of(ctx).pop(BulkRemoveChoice(tag: tag, role: role)),
          ),
        ]),
      );
    }),
  );
}

class BulkTaskChoice {
  const BulkTaskChoice(this.title, this.due, this.description);
  final String title;
  final DateTime due;
  final String description;
}

/// Title and due date of one task that is created for each selected contact.
Future<BulkTaskChoice?> showBulkTaskSheet(BuildContext context, {required int count}) {
  final l = AppLocalizations.of(context);
  final title = TextEditingController();
  final note = TextEditingController();
  var due = DateTime.now().add(const Duration(days: 1));
  return showGlassSheet<BulkTaskChoice>(
    context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      return SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.bulkAddTask, bottom: AppSpace.md),
          GlassField(controller: title, label: l.bulkTaskTitle, autofocus: true, textCapitalization: TextCapitalization.sentences, onChanged: (_) => setS(() {})),
          const SizedBox(height: AppSpace.lg),
          GlassSelectField(
            label: l.bulkDueDate,
            value: MaterialLocalizations.of(ctx).formatMediumDate(due),
            onTap: () async {
              final d = await showDatePicker(context: ctx, initialDate: due, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d != null) setS(() => due = d);
            },
          ),
          const SizedBox(height: AppSpace.lg),
          GlassField(controller: note, label: l.fieldDescription, maxLines: 3, textCapitalization: TextCapitalization.sentences),
          const SizedBox(height: AppSpace.lg),
          SheetButtons(
            secondary: l.cancel,
            onSecondary: () => Navigator.of(ctx).pop(),
            primary: l.bulkCreateTasks(count),
            onPrimary: title.text.trim().isEmpty ? null : () => Navigator.of(ctx).pop(BulkTaskChoice(title.text.trim(), due, note.text.trim())),
          ),
        ]),
      );
    }),
  );
}

class BulkActivityChoice {
  const BulkActivityChoice(this.type, this.title, this.description);
  final ActivityType type;
  final String title;
  final String description;
}

/// A message or note that is logged once for each selected contact.
Future<BulkActivityChoice?> showBulkActivitySheet(BuildContext context, {required int count}) {
  final l = AppLocalizations.of(context);
  final title = TextEditingController();
  final text = TextEditingController();
  var type = ActivityType.message;
  return showGlassSheet<BulkActivityChoice>(
    context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      return SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.bulkLogActivity, bottom: AppSpace.md),
          ChipRow(chips: [
            for (final t in const [ActivityType.message, ActivityType.note])
              PillChip(label: activityTypeLabel(l, t), selected: type == t, onTap: () => setS(() => type = t)),
          ]),
          const SizedBox(height: AppSpace.lg),
          GlassField(controller: title, label: l.bulkTaskTitle, autofocus: true, textCapitalization: TextCapitalization.sentences, onChanged: (_) => setS(() {})),
          const SizedBox(height: AppSpace.lg),
          GlassField(controller: text, label: l.bulkNoteText, maxLines: 3, textCapitalization: TextCapitalization.sentences),
          const SizedBox(height: AppSpace.lg),
          SheetButtons(
            secondary: l.cancel,
            onSecondary: () => Navigator.of(ctx).pop(),
            primary: l.bulkLogFor(count),
            onPrimary: title.text.trim().isEmpty ? null : () => Navigator.of(ctx).pop(BulkActivityChoice(type, title.text.trim(), text.text.trim())),
          ),
        ]),
      );
    }),
  );
}

class BulkMeetingChoice {
  const BulkMeetingChoice(this.title, this.start);
  final String title;
  final DateTime start;
}

/// One meeting with every selected contact attached.
Future<BulkMeetingChoice?> showBulkMeetingSheet(BuildContext context, {required int count}) {
  final l = AppLocalizations.of(context);
  final title = TextEditingController();
  var start = DateTime.now().add(const Duration(days: 1)).copyWith(minute: 0, second: 0, millisecond: 0, microsecond: 0);
  return showGlassSheet<BulkMeetingChoice>(
    context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
      final ml = MaterialLocalizations.of(ctx);
      return SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.bulkAddMeeting, bottom: AppSpace.md),
          GlassField(controller: title, label: l.bulkMeetingTitle, autofocus: true, textCapitalization: TextCapitalization.sentences, onChanged: (_) => setS(() {})),
          const SizedBox(height: AppSpace.lg),
          GlassSelectField(
            label: l.bulkWhen,
            value: '${ml.formatMediumDate(start)} · ${ml.formatTimeOfDay(TimeOfDay.fromDateTime(start))}',
            onTap: () async {
              final d = await showDatePicker(context: ctx, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (d == null || !ctx.mounted) return;
              final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(start));
              setS(() => start = DateTime(d.year, d.month, d.day, t?.hour ?? start.hour, t?.minute ?? start.minute));
            },
          ),
          const SizedBox(height: AppSpace.lg),
          SheetButtons(
            secondary: l.cancel,
            onSecondary: () => Navigator.of(ctx).pop(),
            primary: l.bulkCreateMeeting,
            onPrimary: title.text.trim().isEmpty ? null : () => Navigator.of(ctx).pop(BulkMeetingChoice(title.text.trim(), start)),
          ),
        ]),
      );
    }),
  );
}
