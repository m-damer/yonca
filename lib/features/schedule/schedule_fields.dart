import 'package:flutter/material.dart';
import '../settings/settings_widgets.dart' show SegControl;

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
    final base = reminderLabel(l, minutes, hasTime: hasTime);
    return GlassSelectField(
      label: l.fieldRemindMe,
      value: minutes == null ? base : '$base · ${alarm ? l.reminderTypeAlarm : l.reminderTypeNotification}',
      onTap: () async {
        var a = alarm;
        final r = await showGlassSheet<({int? value, bool alarm})>(
          context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l.fieldReminder, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
              SegControl(
                labels: [l.reminderTypeAlarm, l.reminderTypeNotification],
                selected: a ? 0 : 1,
                onSelect: (i) => setS(() => a = i == 0),
              ),
              const SizedBox(height: 8),
              for (final c in reminderChoices(hasTime: hasTime))
                ListTile(
                  title: Text(reminderLabel(l, c, hasTime: hasTime)),
                  trailing: c == minutes ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(ctx).pop((value: c, alarm: a)),
                ),
            ]),
          ),
        );
        if (r != null) {
          onMinutes(r.value);
          onAlarm(r.alarm);
        }
      },
    );
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
                child: Text(l.fieldRepeat, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
      color: p.surface2,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onRemove,
        child: SizedBox(
          height: 40,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(width: 7),
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(8)),
              child: Text(initials, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.text)),
            ),
            const SizedBox(width: 8),
            Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: p.text)),
            const SizedBox(width: 14),
            if (onRemove != null) ...[Icon(Icons.close, size: 16, color: p.text2), const SizedBox(width: 10)],
          ]),
        ),
      ),
    );
  }
}
