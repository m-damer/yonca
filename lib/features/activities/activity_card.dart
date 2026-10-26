import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/activities_repository.dart';
import '../../data/app_database.dart';
import '../../data/contacts_repository.dart';
import '../../domain/activity_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'activity_labels.dart';
import 'log_activity_page.dart';
import 'voice.dart';

/// Square icon in the type's leaf colour.
class ActivityIcon extends StatelessWidget {
  const ActivityIcon(this.type, {super.key, this.size = 44});
  final ActivityType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: activityTypeColor(p, type), borderRadius: BorderRadius.circular(size * 14 / 44)),
      child: Icon(activityTypeIcon(type), color: activityTypeOnColor(context, p, type), size: size * .5),
    );
  }
}

/// One activity on a Timeline: type icon, headline, contact, outcome, two lines of text, time.
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.item, required this.onTap, this.showContact = true});
  final ActivityItem item;
  final VoidCallback onTap;
  final bool showContact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final a = item.activity;
    final contact = item.contactName ?? (item.type == ActivityType.note ? l.generalNote : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ActivityIcon(item.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text(activityHeadline(l, a),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    Text(formatTime(context, a.occurredAt), style: TextStyle(color: p.text2, fontSize: 12.5)),
                  ]),
                  if (showContact && contact != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(contact, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text2, fontSize: 14)),
                    ),
                  if (item.outcome != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TagPill(outcomeLabel(l, item.outcome!)),
                    ),
                  if (a.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(a.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5)),
                    ),
                  if (a.voicePath != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: VoicePlayer(path: a.voicePath!, durationMs: a.voiceMs),
                    ),
                  if (item.files.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        Icon(Icons.attach_file, size: 16, color: p.text2),
                        const SizedBox(width: 4),
                        Text('${item.files.length}', style: TextStyle(color: p.text2, fontSize: 13)),
                      ]),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Opens a file with the phone's apps; images open in the app.
Future<void> openActivityFile(BuildContext context, ActivityFile f) async {
  final messenger = ScaffoldMessenger.of(context);
  final failed = AppLocalizations.of(context).fileOpenFailed;
  if (f.isImage && File(f.path).existsSync()) {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ImageViewPage(path: f.path, title: f.name)));
    return;
  }
  final r = await OpenFilex.open(f.path);
  if (r.type != ResultType.done) messenger.showSnackBar(SnackBar(content: Text(failed)));
}

class ImageViewPage extends StatelessWidget {
  const ImageViewPage({super.key, required this.path, required this.title});
  final String path;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: InteractiveViewer(child: Center(child: Image.file(File(path)))),
    );
  }
}

/// Read-only detail sheet (design S14). "Open" goes to the activity's own screen (edit and delete).
/// Returns true when the activity was changed or deleted.
Future<bool> showActivitySheet(
  BuildContext context, {
  required ActivityItem item,
  required ActivitiesRepository activities,
  required ContactsRepository contacts,
}) async {
  var changed = false;
  await showGlassSheet<void>(
    context,
    builder: (ctx) => _ActivitySheet(
      item: item,
      onOpen: () async {
        Navigator.of(ctx).pop();
        final r = await Navigator.of(context).push<int>(MaterialPageRoute(
          builder: (_) => LogActivityPage(activities: activities, contacts: contacts, id: item.activity.id),
        ));
        if (r != null) changed = true;
      },
    ),
  );
  return changed;
}

class _ActivitySheet extends StatelessWidget {
  const _ActivitySheet({required this.item, required this.onOpen});
  final ActivityItem item;
  final VoidCallback onOpen;

  Future<void> _openMap(BuildContext context, String link) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).launchFailed;
    final v = link.trim();
    final uri = Uri.parse(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:(//|[^0-9/])').hasMatch(v) ? v : 'https://$v');
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final a = item.activity;
    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: p.text2, fontSize: 12.5)),
            Text(value, style: const TextStyle(fontSize: 16)),
          ]),
        );
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          ActivityIcon(item.type),
          const SizedBox(width: 12),
          Expanded(child: Text(activityHeadline(l, a), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
        ]),
        line(l.fieldWhen, formatWhen(context, a.occurredAt)),
        if (item.contactName != null) line(l.fieldContact, item.contactName!),
        if (item.outcome != null) line(l.fieldOutcome, outcomeLabel(l, item.outcome!)),
        if (a.place.isNotEmpty) line(l.fieldPlace, a.place),
        if (a.mapLink.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => _openMap(context, a.mapLink),
              icon: const Icon(Icons.place_outlined),
              label: Text(l.actionMap),
            ),
          ),
        if (a.description.isNotEmpty) line(item.type == ActivityType.note ? l.fieldNoteText : l.fieldDescription, a.description),
        if (a.voicePath != null) ...[
          const SizedBox(height: 14),
          VoicePlayer(path: a.voicePath!, durationMs: a.voiceMs),
        ],
        if (item.files.isNotEmpty) ...[
          SectionLabel(l.attachments),
          for (final f in item.files)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(f.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined, color: p.primary),
              title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => openActivityFile(context, f),
            ),
        ],
        const SizedBox(height: 18),
        PillButton(label: l.openActivity, outlined: true, height: 50, onPressed: onOpen),
      ]),
    );
  }
}
