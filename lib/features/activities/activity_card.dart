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
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
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
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

/// Activity detail page (design Rec NView): headline, contact and time, the text, voice note and files,
/// with Delete and Edit. Returns true when the activity was changed or deleted.
Future<bool> showActivitySheet(
  BuildContext context, {
  required ActivityItem item,
  required ActivitiesRepository activities,
  required ContactsRepository contacts,
}) async {
  final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
    builder: (_) => ActivityViewPage(item: item, activities: activities, contacts: contacts),
  ));
  return changed ?? false;
}

class ActivityViewPage extends StatefulWidget {
  const ActivityViewPage({super.key, required this.item, required this.activities, required this.contacts});
  final ActivityItem item;
  final ActivitiesRepository activities;
  final ContactsRepository contacts;

  @override
  State<ActivityViewPage> createState() => _ActivityViewPageState();
}

class _ActivityViewPageState extends State<ActivityViewPage> {
  late ActivityItem _item = widget.item;
  bool _changed = false;

  Future<void> _openMap(String link) async {
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

  Future<void> _edit() async {
    final r = await Navigator.of(context).push<int>(MaterialPageRoute(
      builder: (_) => LogActivityPage(activities: widget.activities, contacts: widget.contacts, id: _item.activity.id),
    ));
    if (r == null || !mounted) return;
    _changed = true;
    if (r == -1) {
      Navigator.of(context).pop(true);
      return;
    }
    final fresh = await widget.activities.get(_item.activity.id);
    if (fresh != null && mounted) setState(() => _item = fresh);
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteActivityTitle),
        content: Text(l.deleteActivityBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true) return;
    final paths = await widget.activities.delete(_item.activity.id);
    for (final path in paths) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    nav.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final item = _item;
    final a = item.activity;
    final contact = item.contactName ?? (item.type == ActivityType.note ? l.generalNote : null);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GlassBackdrop(
          child: Column(children: [
            HeaderBand(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(children: [
                GlassIconButton(icon: Icons.arrow_back, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 14),
                Expanded(child: Text(activityTypeLabel(l, item.type), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: p.onHeader))),
                GlassIconButton(icon: Icons.edit_outlined, onHeader: true, onTap: _edit),
              ]),
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: [
                Text(item.type == ActivityType.note && a.title.isNotEmpty ? a.title : activityHeadline(l, a),
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: p.text)),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.person_outline, size: 20, color: p.text2),
                  const SizedBox(width: 8),
                  Flexible(child: Text([if (contact != null) contact, formatWhen(context, a.occurredAt)].join('  ·  '), style: TextStyle(color: p.text2, fontSize: 14))),
                ]),
                if (item.outcome != null) ...[
                  const SizedBox(height: 10),
                  Align(alignment: AlignmentDirectional.centerStart, child: TagPill(outcomeLabel(l, item.outcome!), large: true)),
                ],
                if (a.place.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: a.mapLink.isEmpty ? null : () => _openMap(a.mapLink),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Icon(Icons.location_on_outlined, color: p.primary),
                            const SizedBox(width: 12),
                            Expanded(child: Text(a.place, style: const TextStyle(fontSize: 14))),
                            if (a.mapLink.isNotEmpty) Text(l.actionMap, style: TextStyle(color: p.primary, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ],
                if (a.description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  GlassCard(padding: const EdgeInsets.all(16), child: Text(a.description, style: const TextStyle(fontSize: 14, height: 1.45))),
                ],
                if (a.voicePath != null) ...[
                  SectionLabel(l.voiceNote),
                  GlassCard(padding: const EdgeInsets.all(12), child: VoicePlayer(path: a.voicePath!, durationMs: a.voiceMs)),
                ],
                if (item.files.isNotEmpty) ...[
                  SectionLabel(l.attachments),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(children: [
                        for (final f in item.files)
                          InkWell(
                            onTap: () => openActivityFile(context, f),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(8)),
                                  child: Icon(f.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined, color: p.onPrimaryContainer),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                              ]),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: PillButton(label: l.delete, icon: Icons.delete_outline, outlined: true, danger: true, height: 48, onPressed: _delete)),
                  const SizedBox(width: 12),
                  Expanded(child: PillButton(label: l.edit, icon: Icons.edit_outlined, height: 48, onPressed: _edit)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
