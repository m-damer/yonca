import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../core/format.dart' show dfmt;
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
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

/// Soft grey tile with the type's icon in the accent colour.
class ActivityIcon extends StatelessWidget {
  const ActivityIcon(this.type, {super.key, this.size = 36});
  final ActivityType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)),
      child: Icon(activityTypeIcon(type), color: p.primary, size: 20),
    );
  }
}

/// One activity: type icon, headline, contact and detail, text, time.
/// With [compact] it is a row inside a grouped card (the contact's own timeline).
class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.item, required this.onTap, this.showContact = true, this.compact = false, this.showDate = false});

  /// Day instead of time on the right (filtered Timeline).
  final bool showDate;
  final ActivityItem item;
  final VoidCallback onTap;
  final bool showContact;
  final bool compact;

  String _title(AppLocalizations l) {
    final a = item.activity;
    final o = item.outcome == null ? null : outcomeLabel(l, item.outcome!);
    switch (item.type) {
      case ActivityType.call:
        return o == null ? l.typeCall : '${l.typeCall} · $o';
      case ActivityType.visit:
        return a.place.isNotEmpty ? '${l.typeVisit} · ${a.place}' : (o == null ? l.typeVisit : '${l.typeVisit} · $o');
      case ActivityType.message:
        return [l.typeMessage, channelLabel(l, a.channel)].where((x) => x.isNotEmpty).join(' · ');
      case ActivityType.note:
        return a.title;
    }
  }

  String _detail(AppLocalizations l) {
    final a = item.activity;
    switch (item.type) {
      case ActivityType.call:
        return [if (a.durationMinutes != null) '${a.durationMinutes} min', directionLabel(l, a.direction).toLowerCase()].where((x) => x.isNotEmpty).join(' ');
      case ActivityType.visit:
        return a.place.isNotEmpty && item.outcome != null ? outcomeLabel(l, item.outcome!) : '';
      case ActivityType.message:
        return directionLabel(l, a.direction);
      case ActivityType.note:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final a = item.activity;
    final contact = item.contactName ?? (item.type == ActivityType.note ? l.generalNote : null);
    final detail = _detail(l);
    final String sub;
    if (compact) {
      sub = [formatWhenShort(context, a.occurredAt), if (a.description.isNotEmpty) a.description].join(' · ');
    } else {
      sub = [if (showContact && contact != null) contact, if (detail.isNotEmpty) detail].join(' · ');
    }
    final row = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.fromLTRB(compact ? 14 : 16, compact ? 11 : 14, compact ? 14 : 16, compact ? 11 : 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ActivityIcon(item.type),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(_title(l),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: compact ? 14.5 : 15, height: compact ? 20.3 / 14.5 : 19 / 15, fontWeight: compact ? FontWeight.w500 : FontWeight.w600)),
                ),
                if (!compact) Padding(padding: const EdgeInsets.only(left: 8), child: Text(showDate ? dfmt(DateFormat('d MMM', Localizations.localeOf(context).toString()), a.occurredAt) : formatTime(context, a.occurredAt), style: TextStyle(color: p.text2, fontSize: 12, height: 16.8 / 12))),
              ]),
              if (sub.isNotEmpty) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text2, fontSize: compact ? 13 : 13.5, height: compact ? 18.2 / 13 : 18.9 / 13.5)),
              if (!compact && a.description.isNotEmpty)
                Text(a.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text2, fontSize: 13, height: 18.2 / 13)),
              if (a.voicePath != null)
                Padding(padding: const EdgeInsets.only(top: 8), child: VoicePlayer(path: a.voicePath!, durationMs: a.voiceMs)),
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
    );
    if (compact) return Material(type: MaterialType.transparency, child: row);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(padding: EdgeInsets.zero, child: Material(type: MaterialType.transparency, child: row)),
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
  if (f.name.toLowerCase().endsWith('.pdf') && File(f.path).existsSync()) {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PdfViewPage(path: f.path, title: f.name)));
    return;
  }
  final r = await OpenFilex.open(f.path);
  if (r.type != ResultType.done) messenger.showSnackBar(SnackBar(content: Text(failed)));
}

class PdfViewPage extends StatefulWidget {
  const PdfViewPage({super.key, required this.path, required this.title});
  final String path;
  final String title;

  @override
  State<PdfViewPage> createState() => _PdfViewPageState();
}

class _PdfViewPageState extends State<PdfViewPage> {
  late final PdfControllerPinch _ctl = PdfControllerPinch(document: PdfDocument.openFile(widget.path));

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF111816),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(children: [
              GlassIconButton(icon: Icons.chevron_left, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              Expanded(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white))),
              GlassIconButton(icon: Icons.ios_share, tooltip: l.shareLabel, onTap: () => Share.shareXFiles([XFile(widget.path)])),
              const SizedBox(width: 8),
              GlassIconButton(icon: Icons.open_in_new, onTap: () => OpenFilex.open(widget.path)),
            ]),
          ),
          Expanded(child: PdfViewPinch(controller: _ctl, backgroundDecoration: const BoxDecoration(color: Color(0xFF111816)))),
          Padding(
            padding: const EdgeInsets.only(bottom: 14, top: 8),
            child: PdfPageNumber(
              controller: _ctl,
              builder: (_, state, page, pages) => Text('${page ?? 1}/${pages ?? 1}', style: const TextStyle(fontSize: 13, color: Color(0xB3FFFFFF))),
            ),
          ),
        ]),
      ),
    );
  }
}

class ImageViewPage extends StatelessWidget {
  const ImageViewPage({super.key, required this.path, required this.title});
  final String path;
  final String title;

  String _size() {
    try {
      final n = File(path).lengthSync();
      return n >= 1048576 ? '${(n / 1048576).toStringAsFixed(1)} MB' : '${(n / 1024).ceil()} KB';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF111816),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(children: [
              GlassIconButton(icon: Icons.chevron_left, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white))),
              GlassIconButton(icon: Icons.ios_share, tooltip: l.shareLabel, onTap: () => Share.shareXFiles([XFile(path)])),
              const SizedBox(width: 8),
              GlassIconButton(icon: Icons.open_in_new, onTap: () => OpenFilex.open(path)),
            ]),
          ),
          Expanded(child: InteractiveViewer(maxScale: 5, child: Center(child: Image.file(File(path))))),
          Padding(padding: const EdgeInsets.only(bottom: 14, top: 8), child: Text(l.pinchZoom(_size()), style: const TextStyle(fontSize: 13, color: Color(0xB3FFFFFF)))),
        ]),
      ),
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
  final l = AppLocalizations.of(context);
  final p = context.palette;
  final a = item.activity;
  final contact = item.contactName ?? (item.type == ActivityType.note ? l.generalNote : null);
  final headline = a.title.isNotEmpty ? a.title : activityTypeLabel(l, item.type);
  final open = await showGlassSheet<bool>(
    context,
    builder: (ctx) => SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)),
              child: Icon(activityTypeIcon(item.type), size: 20, color: p.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, height: 27 / 20, fontWeight: FontWeight.w600)),
                Text([activityTypeLabel(l, item.type), if (contact != null) contact, formatWhen(ctx, a.occurredAt)].join(' · '),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, height: 18.9 / 13.5, color: p.text2)),
              ]),
            ),
          ]),
        ),
        if (a.description.isNotEmpty)
          Padding(padding: const EdgeInsets.fromLTRB(0, 4, 0, 8), child: Text(a.description, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, height: 23.2 / 16))),
        if (a.voicePath != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: VoicePlayer(path: a.voicePath!, durationMs: a.voiceMs)),
        if (item.files.isNotEmpty) ...[
          SectionLabel(l.filesCaps, padding: const EdgeInsets.fromLTRB(4, 8, 4, 8)),
          for (final f in item.files.take(2))
            GlassCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(8)), child: Icon(f.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined, size: 20, color: p.primary)),
                title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                trailing: Icon(Icons.chevron_right, color: p.text2),
                onTap: () => openActivityFile(ctx, f),
              ),
            ),
        ],
        const SizedBox(height: 16),
        PillButton(label: item.type == ActivityType.note ? l.openNoteBtn : l.openActivityBtn, icon: Icons.edit_outlined, onPressed: () => Navigator.of(ctx).pop(true)),
      ]),
    ),
  );
  if (open != true || !context.mounted) return false;
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
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Row(children: [
                GlassIconButton(icon: Icons.chevron_left, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 12),
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
