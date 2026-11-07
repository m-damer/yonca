import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../contacts/contact_details_page.dart';
import 'event_form_page.dart';
import 'schedule_view_pages.dart';

/// Opens what a reminder, alarm or notification is about: the task or meeting page (where it can be marked done),
/// or the contact for a contact event. Never the edit form. [replace] swaps the current page instead of stacking on it.
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
    default:
      final e = await s.getEvent(id);
      if (e != null) {
        page = ContactDetailsPage(repo: contacts, activities: c.activities, schedule: s, deals: c.deals, fields: c.fields, id: e.contactId);
      } else {
        page = EventFormPage(schedule: s, contacts: contacts, id: id);
      }
  }
  final route = MaterialPageRoute<void>(builder: (_) => page);
  if (replace) {
    await nav.pushReplacement(route);
  } else {
    await nav.push(route);
  }
}
