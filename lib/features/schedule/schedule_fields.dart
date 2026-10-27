import 'package:flutter/material.dart';

import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/palette.dart';
import 'schedule_labels.dart';

/// "Remind me" select plus, when a reminder is set, the Alarm / Notification choice (design Cal Task / Meet).
class ReminderFields extends StatelessWidget {
  const ReminderFields({
    super.key,
    required this.hasTime,
    required this.minutes,
    required this.alarm,
    required this.onMinutes,
    required this.onAlarm,
  });
  final bool hasTime;
  final int? minutes;
  final bool alarm;
  final ValueChanged<int?> onMinutes;
  final ValueChanged<bool> onAlarm;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GlassSelectField(
        label: l.fieldRemindMe,
        value: reminderLabel(l, minutes, hasTime: hasTime),
        onTap: () async {
          final r = await pickReminder(context, hasTime: hasTime, current: minutes);
          if (r != null) onMinutes(r.value);
        },
      ),
      if (minutes != null) ...[
        SectionLabel(l.fieldReminderType),
        Wrap(spacing: 8, runSpacing: 8, children: [
          PillChip(label: l.reminderTypeAlarm, selected: alarm, onTap: () => onAlarm(true)),
          PillChip(label: l.reminderTypeNotification, selected: !alarm, onTap: () => onAlarm(false)),
        ]),
      ],
    ]);
  }
}

/// Repeat as a select field that opens a short list.
class RepeatSelect extends StatelessWidget {
  const RepeatSelect({super.key, required this.value, required this.onChanged});
  final Repeat value;
  final ValueChanged<Repeat> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GlassSelectField(
      label: l.fieldRepeat,
      value: repeatLabel(l, value),
      onTap: () async {
        final r = await showGlassSheet<Repeat>(
          context,
          builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(l.fieldRepeat, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
            ),
            for (final r in Repeat.values)
              ListTile(
                title: Text(repeatLabel(l, r)),
                trailing: r == value ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(ctx).pop(r),
              ),
          ]),
        );
        if (r != null) onChanged(r);
      },
    );
  }
}

/// A person chip: avatar tile with initials, then the name; the ✕ shows when it can be removed.
class AttendeeChip extends StatelessWidget {
  const AttendeeChip({super.key, required this.name, this.onRemove});
  final String name;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final initials = name.trim().isEmpty ? '' : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.characters.first.toUpperCase()).join();
    return Material(
      color: Colors.transparent,
      shape: StadiumBorder(side: BorderSide(color: p.outline, width: 1.5)),
      child: InkWell(
        onTap: onRemove,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 14, 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle),
              child: Text(initials, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.onPrimary)),
            ),
            const SizedBox(width: 8),
            Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: p.text)),
            if (onRemove != null) ...[const SizedBox(width: 6), Icon(Icons.close, size: 16, color: p.text2)],
          ]),
        ),
      ),
    );
  }
}
