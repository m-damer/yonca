import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../core/format.dart';

import '../../data/app_database.dart';
import '../../domain/activity_models.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/palette.dart';

String activityTypeLabel(AppLocalizations l, ActivityType t) => switch (t) {
      ActivityType.call => l.typeCall,
      ActivityType.visit => l.typeVisit,
      ActivityType.message => l.typeMessage,
      ActivityType.note => l.typeNote,
    };

IconData activityTypeIcon(ActivityType t) => switch (t) {
      ActivityType.call => Icons.call_outlined,
      ActivityType.visit => Icons.place_outlined,
      ActivityType.message => Icons.chat_bubble_outline,
      ActivityType.note => Icons.sticky_note_2_outlined,
    };

/// One of the four logo greens per type, so cards of one type look alike.
Color activityTypeColor(YoncaPalette p, ActivityType t) => p.leaves[t.index % p.leaves.length];

Color activityTypeOnColor(BuildContext context, YoncaPalette p, ActivityType t) =>
    (t.index == 1 || Theme.of(context).brightness == Brightness.dark) ? p.onAccent : Colors.white;

String outcomeLabel(AppLocalizations l, Outcome o) => switch (o.key) {
      'interested' => l.outcomeInterested,
      'needsTime' => l.outcomeNeedsTime,
      'notInterested' => l.outcomeNotInterested,
      'noAnswer' => l.outcomeNoAnswer,
      _ => o.name,
    };

String directionLabel(AppLocalizations l, String d) => switch (d) {
      'in' => l.dirIncoming,
      'out' => l.dirOutgoing,
      'sent' => l.dirSent,
      'received' => l.dirReceived,
      _ => '',
    };

String channelLabel(AppLocalizations l, String c) => c == 'email' ? l.actionEmail : l.actionWhatsApp;

/// "Call · Outgoing · 12 min", the place for a visit, the title for a note.
String activityHeadline(AppLocalizations l, Activity a) {
  final t = activityTypeFromName(a.type);
  switch (t) {
    case ActivityType.call:
      return [
        l.typeCall,
        directionLabel(l, a.direction),
        if (a.durationMinutes != null) '${a.durationMinutes} min',
      ].where((s) => s.isNotEmpty).join(' · ');
    case ActivityType.visit:
      return a.place.isNotEmpty ? '${l.typeVisit} · ${a.place}' : l.typeVisit;
    case ActivityType.message:
      return [l.typeMessage, channelLabel(l, a.channel), directionLabel(l, a.direction)]
          .where((s) => s.isNotEmpty)
          .join(' · ');
    case ActivityType.note:
      return a.title;
  }
}

String formatWhen(BuildContext context, DateTime d) {
  final locale = Localizations.localeOf(context).toString();
  return '${dfmt(DateFormat.yMMMd(locale), d)} · ${dfmt(DateFormat.jm(locale), d)}';
}

/// "Today, 09:12", "Yesterday, 16:20" or "12 Oct".
String formatWhenShort(BuildContext context, DateTime d) {
  final l = AppLocalizations.of(context);
  final n = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).difference(DateTime(d.year, d.month, d.day)).inDays;
  if (n == 0) return '${l.groupToday}, ${formatTime(context, d)}';
  if (n == 1) return l.groupYesterday;
  return dfmt(DateFormat.MMMd(Localizations.localeOf(context).toString()), d);
}

String formatTime(BuildContext context, DateTime d) {
  final loc = Localizations.localeOf(context).toString();
  return dfmt(MediaQuery.of(context).alwaysUse24HourFormat ? DateFormat.Hm(loc) : DateFormat.jm(loc), d);
}

String formatDuration(int ms) {
  final s = (ms / 1000).round();
  return '${(s ~/ 60).toString().padLeft(1, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}
