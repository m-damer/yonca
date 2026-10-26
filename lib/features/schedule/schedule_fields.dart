import 'package:flutter/material.dart';

import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import 'schedule_labels.dart';

/// Reminder picker plus the "ring as an alarm" switch, shared by the task and meeting forms.
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
    return Column(children: [
      GlassSelectField(
        label: l.fieldReminder,
        value: reminderLabel(l, minutes, hasTime: hasTime),
        onTap: () async {
          final r = await pickReminder(context, hasTime: hasTime, current: minutes);
          if (r != null) onMinutes(r.value);
        },
      ),
      if (minutes != null)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.ringAsAlarm),
          value: alarm,
          onChanged: onAlarm,
        ),
    ]);
  }
}

/// Repeat choice as chips.
class RepeatChips extends StatelessWidget {
  const RepeatChips({super.key, required this.value, required this.onChanged});
  final Repeat value;
  final ValueChanged<Repeat> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final r in Repeat.values)
        PillChip(label: repeatLabel(l, r), selected: value == r, check: true, onTap: () => onChanged(r)),
    ]);
  }
}
