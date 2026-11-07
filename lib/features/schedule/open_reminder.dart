import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../domain/stats_models.dart';
import '../stats/target_page.dart';
import 'event_view_page.dart';
import 'schedule_view_pages.dart';

/// Opens what a reminder, alarm or notification is about: the task or meeting page (where it can be marked done),
/// the event page, or the target page. Never the edit form. [replace] swaps the current page instead of stacking on it.
Future<void> openReminder(BuildContext context, AppController c, String kind, int id, {bool replace = false}) async {
  final s = c.schedule, contacts = c.contacts;
  if (s == null || contacts == null) return;
  final nav = Navigator.of(context);
  Widget page;
  switch (kind) {
    case 'task':
      page = TaskViewPage(schedule: s, contacts: contacts, id: id);
    case 'meeting':
      page = MeetingViewPage(schedule: s, contacts: contacts, id: id);
    case 'target':
      if (id < 0 || id >= Metric.values.length) return;
      page = TargetPage(controller: c, metric: Metric.values[id]);
    default:
      page = EventViewPage(controller: c, id: id);
  }
  final route = MaterialPageRoute<void>(builder: (_) => page);
  if (replace) {
    await nav.pushReplacement(route);
  } else {
    await nav.push(route);
  }
}
