import 'package:flutter/material.dart';

import '../../data/activities_repository.dart';
import '../../data/contacts_repository.dart';
import '../../data/deals_repository.dart';
import '../../data/fields_repository.dart';
import '../../data/schedule_repository.dart';
import '../../domain/activity_models.dart';
import '../contacts/contact_details_page.dart';
import '../deals/deal_detail_page.dart';
import '../schedule/schedule_view_pages.dart';

/// What a Timeline line can open: the repositories the target screens need.
class SystemEventTargets {
  const SystemEventTargets({required this.contacts, this.activities, this.schedule, this.deals, this.fields, this.onOpenContacts});
  final ContactsRepository contacts;
  final ActivitiesRepository? activities;
  final ScheduleRepository? schedule;
  final DealsRepository? deals;
  final FieldsRepository? fields;

  /// Opens the list of an "N contacts added" line.
  final void Function(List<int> ids)? onOpenContacts;
}

/// Takes the user from a Timeline line to the thing it is about: the deal, the task, the meeting or the contact.
/// Returns false when nothing can be opened for it.
bool canOpenSystemEvent(SystemEvent e, SystemEventTargets t) => _action(e, t) != null;

void openSystemEvent(BuildContext context, SystemEvent e, SystemEventTargets t) => _action(e, t)?.call(context);

void Function(BuildContext)? _action(SystemEvent e, SystemEventTargets t) {
  Future<void> push(BuildContext c, Widget page) => Navigator.of(c).push<void>(MaterialPageRoute(builder: (_) => page));
  void contact(int id, BuildContext c) => push(c, ContactDetailsPage(repo: t.contacts, activities: t.activities, schedule: t.schedule, deals: t.deals, fields: t.fields, id: id));
  final id = e.refId;
  switch (e.kind) {
    case SystemEventKind.contactAdded:
      if (e.isBatch) return t.onOpenContacts == null ? null : (c) => t.onOpenContacts!(e.contactIds);
      final cid = e.contactId;
      return cid == null ? null : (c) => contact(cid, c);
    case SystemEventKind.taskDone:
      if (id != null && t.schedule != null) return (c) => push(c, TaskViewPage(schedule: t.schedule!, contacts: t.contacts, id: id));
    case SystemEventKind.meetingHeld:
      if (id != null && t.schedule != null) return (c) => push(c, MeetingViewPage(schedule: t.schedule!, contacts: t.contacts, id: id));
    case SystemEventKind.dealCreated || SystemEventKind.dealMoved || SystemEventKind.dealWon || SystemEventKind.dealLost:
      if (id != null && t.deals != null) return (c) => push(c, DealDetailPage(deals: t.deals!, contacts: t.contacts, id: id, fields: t.fields, activities: t.activities, schedule: t.schedule));
  }
  final cid = e.contactId;
  return cid == null ? null : (c) => contact(cid, c);
}
