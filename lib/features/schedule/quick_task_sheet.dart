import 'package:flutter/material.dart';

import '../../data/contacts_repository.dart';
import '../../data/schedule_repository.dart';
import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import 'schedule_labels.dart';
import 'task_form_page.dart';

/// Quick task (design Rec TQuick): a title and a day, Save; "More options" opens the full form.
/// Returns the saved task id, or null when cancelled.
Future<int?> showQuickTask(
  BuildContext context, {
  required ScheduleRepository schedule,
  required ContactsRepository contacts,
  int? contactId,
  DateTime? day,
}) async {
  final l = AppLocalizations.of(context);
  final title = TextEditingController();
  final today = dayOnly(DateTime.now());
  var due = day == null ? today.add(const Duration(days: 1)) : dayOnly(day);
  final result = await showGlassSheet<String>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final isToday = due == today;
        final isTomorrow = due == today.add(const Duration(days: 1));
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(l.taskNew, bottom: 12),
            GlassField(controller: title, label: l.fieldTaskTitle, autofocus: true, textCapitalization: TextCapitalization.sentences, onChanged: (_) => setSheet(() {})),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              PillChip(label: l.quickToday, icon: Icons.calendar_today_outlined, selected: isToday, onTap: () => setSheet(() => due = today)),
              PillChip(label: l.quickTomorrow, icon: Icons.calendar_today_outlined, selected: isTomorrow, onTap: () => setSheet(() => due = today.add(const Duration(days: 1)))),
              PillChip(
                label: isToday || isTomorrow ? l.quickDate : formatDay(ctx, due),
                icon: Icons.edit_calendar_outlined,
                selected: !isToday && !isTomorrow,
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: due, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setSheet(() => due = dayOnly(d));
                },
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                flex: 145,
                child: TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.of(ctx).pop('more'),
                  child: Text(l.moreOptions, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(flex: 203, child: PillButton(label: l.save, height: 48, onPressed: title.text.trim().isEmpty ? null : () => Navigator.of(ctx).pop('save'))),
            ]),
          ],
        );
      },
    ),
  );
  final text = title.text.trim();
  if (result == 'save' && text.isNotEmpty) {
    return schedule.saveTask(TaskInput(title: text, contactId: contactId, dueAt: due));
  }
  if (result == 'more' && context.mounted) {
    return Navigator.of(context).push<int>(MaterialPageRoute(
      builder: (_) => TaskFormPage(schedule: schedule, contacts: contacts, contactId: contactId, initialTitle: text, initialDue: due),
    ));
  }
  return null;
}
