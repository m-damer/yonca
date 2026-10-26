import 'package:home_widget/home_widget.dart';

import '../l10n/app_localizations.dart';
import 'schedule_repository.dart';

/// Writes today's items for the home-screen widget and asks Android to redraw it.
Future<void> syncHomeWidget(ScheduleRepository schedule, AppLocalizations l, {DateTime? now}) async {
  try {
    final t = now ?? DateTime.now();
    final start = DateTime(t.year, t.month, t.day);
    final items = await schedule.itemsBetween(start, start.add(const Duration(days: 1)), includeDone: false);
    String hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final lines = items.take(4).map((i) => i.hasTime ? '${hhmm(i.at)}  ${i.title}' : i.title).join('\n');
    await HomeWidget.saveWidgetData<String>('title', l.widgetTodayTitle(items.length));
    await HomeWidget.saveWidgetData<String>('lines', items.isEmpty ? l.widgetNothing : lines);
    await HomeWidget.saveWidgetData<String>('add_label', l.newContact);
    await HomeWidget.saveWidgetData<String>('search_label', l.shortcutSearch);
    await HomeWidget.updateWidget(androidName: 'TodayWidgetProvider');
  } catch (_) {
    // No widget on this platform (tests, desktop).
  }
}
