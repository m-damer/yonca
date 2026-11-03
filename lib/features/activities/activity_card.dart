import 'dart:io';

import 'package:flutter/material.dart';

import '../../shared/ds.dart';
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
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';

/// Soft grey tile with the type's icon in the accent colour.
class ActivityIcon extends StatelessWidget {
  const ActivityIcon(this.type, {super.key, this.size = AppControl.tile});
  final ActivityType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconTile(icon: activityTypeIcon(type), size: size);
  }
}

/// One activity: type icon, headline, contact and detail, text, time.
/// With [compact] it is a row inside a grouped card (the contact's own timeline).
/// A note that only carries attached files (added from the Files tab) is a document or a photo, not a note.
bool isAttachmentOnly(ActivityItem item) =>
    item.type == ActivityType.note && item.files.isNotEmpty && item.activity.description.trim().isEmpty && item.activity.voicePath == null;

IconData activityItemIcon(ActivityItem item) => isAttachmentOnly(item) ? (item.files.every((f) => f.isImage) ? Lu.image : Lu.file) : activityTypeIcon(item.type);

class ActivityCard extends StatelessWidget {
  const ActivityCard({super.key, required this.item, required this.onTap, this.showContact = true, this.compact = false, this.showDate = false});

  /// Day instead of time on the right (filtered Timeline).
  final bool showDate;
  final ActivityItem item;
  final VoidCallback onTap;
  final bool showContact;
  final bool compact;

  String _typeLabel(AppLocalizations l) => isAttachmentOnly(item) ? (item.files.every((f) => f.isImage) ? l.typePhoto : l.typeDocument) : switch (item.type) {
        ActivityType.call => l.typeCall,
        ActivityType.visit => l.typeVisit,
        ActivityType.message => l.typeMessage,
        ActivityType.note => l.typeNote,
      };

  /// The line under the type in a contact's own timeline: the note's title, the call's outcome, the visit's place, the message's channel.
  String _subject(AppLocalizations l) {
    final a = item.activity;
    final o = item.outcome == null ? null : outcomeLabel(l, item.outcome!);
    switch (item.type) {
      case ActivityType.call:
        return o ?? '';
      case ActivityType.visit:
        return a.place.isNotEmpty ? a.place : (o ?? '');
      case ActivityType.message:
        return channelLabel(l, a.channel);
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
    final row = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: EdgeInsets.fromLTRB(compact ? AppSpace.lg : AppSpace.lg, compact ? AppSpace.md : AppSpace.lg, compact ? AppSpace.lg : AppSpace.lg, compact ? AppSpace.md : AppSpace.lg),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconTile(icon: activityItemIcon(item), size: AppControl.tile),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Line 1: the type (small, grey), with the contact in the global Timeline, and the date or time at the opposite end.
              Row(children: [
                Expanded(child: Text([_typeLabel(l), if (!compact && showContact && contact != null) contact].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text2, fontSize: AppFont.meta, height: AppLine.normal))),
                const SizedBox(width: AppSpace.sm),
                Text(
                  compact ? formatWhenShort(context, a.occurredAt) : (showDate ? dfmt(DateFormat('d MMM', Localizations.localeOf(context).toString()), a.occurredAt) : formatTime(context, a.occurredAt)),
                  style: TextStyle(color: p.text2, fontSize: AppFont.meta, height: AppLine.normal),
                ),
              ]),
              // Line 2: the title.
              if (_subject(l).isNotEmpty)
                Text(_subject(l), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppFont.label, height: AppLine.normal, fontWeight: FontWeight.w500)),
              // Line 3: the description, up to three lines.
              if ([if (detail.isNotEmpty) detail, if (a.description.isNotEmpty) a.description].isNotEmpty)
                Text([if (detail.isNotEmpty) detail, if (a.description.isNotEmpty) a.description].join(' · '),
                    maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text2, fontSize: AppFont.meta, height: AppLine.normal)),
              if (item.type == ActivityType.note && !isAttachmentOnly(item))
                Padding(padding: const EdgeInsets.only(top: AppSpace.xs), child: Text(l.readLabel, style: TextStyle(color: p.primary, fontSize: AppFont.meta, height: AppLine.normal, fontWeight: FontWeight.w700))),
              if (a.voicePath != null)
                Padding(padding: const EdgeInsets.only(top: AppSpace.sm), child: VoicePlayer(path: a.voicePath!, durationMs: a.voiceMs)),
              if (item.files.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  child: Row(children: [
                    Icon(Lu.paperclip, size: AppIcon.sm, color: p.text2),
                    const SizedBox(width: AppSpace.xs),
                    Text('${item.files.length}', style: TextStyle(color: p.text2, fontSize: AppFont.meta)),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
    if (compact) return Material(type: MaterialType.transparency, child: row);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
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
      backgroundColor: context.palette.viewerBg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.sm),
            child: Row(children: [
              GlassIconButton(icon: Lu.chevronLeft, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: AppSpace.md),
              Expanded(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.lead, fontWeight: FontWeight.w600, color: context.palette.onMedia))),
              GlassIconButton(icon: Lu.share, tooltip: l.shareLabel, onTap: () => Share.shareXFiles([XFile(widget.path)])),
              const SizedBox(width: AppSpace.sm),
              GlassIconButton(icon: Lu.externalLink, onTap: () => OpenFilex.open(widget.path)),
            ]),
          ),
          Expanded(child: PdfViewPinch(controller: _ctl, backgroundDecoration: BoxDecoration(color: context.palette.viewerBg))),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.lg, top: AppSpace.sm),
            child: PdfPageNumber(
              controller: _ctl,
              builder: (_, state, page, pages) => Text('$page/$pages', style: TextStyle(fontSize: AppFont.meta, color: context.palette.onViewer)),
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
      backgroundColor: context.palette.viewerBg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.sm),
            child: Row(children: [
              GlassIconButton(icon: Lu.chevronLeft, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: AppSpace.md),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.lead, fontWeight: FontWeight.w600, color: context.palette.onMedia))),
              GlassIconButton(icon: Lu.share, tooltip: l.shareLabel, onTap: () => Share.shareXFiles([XFile(path)])),
              const SizedBox(width: AppSpace.sm),
              GlassIconButton(icon: Lu.externalLink, onTap: () => OpenFilex.open(path)),
            ]),
          ),
          Expanded(child: InteractiveViewer(maxScale: 5, child: Center(child: Image.file(File(path))))),
          Padding(padding: const EdgeInsets.only(bottom: AppSpace.lg, top: AppSpace.sm), child: Text(l.pinchZoom(_size()), style: TextStyle(fontSize: AppFont.meta, color: context.palette.onViewer))),
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
  final locale = Localizations.localeOf(context).toString();
  final open = await showGlassSheet<bool>(
    context,
    builder: (ctx) {
      // The sheet takes about 88% of the screen; the handle, padding and safe areas are taken off.
      final media = MediaQuery.of(ctx);
      final height = media.size.height * .88 - media.padding.top - AppSpace.md - AppSpace.xxl - AppSpace.xl - AppSpace.xxs;
      final day = dfmt(DateFormat.yMMMMEEEEd(locale), a.occurredAt);
      Widget metaLine(IconData icon, String text) => Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: Row(children: [
              Icon(icon, size: AppIcon.sm, color: p.text2),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.label, height: AppLine.normal, color: p.text2))),
            ]),
          );
      return SizedBox(
        height: height,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Header: the type icon and the title.
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            IconTile(icon: activityItemIcon(item), size: AppControl.md),
            const SizedBox(width: AppSpace.md),
            Expanded(child: Text(headline, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppFont.title, height: AppLine.snug, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: AppSpace.lg),
          // Under it: the contact, then the day and the time.
          if (contact != null) metaLine(Lu.user, contact),
          metaLine(Lu.calendar, '$day · ${formatTime(ctx, a.occurredAt)}'),
          const SizedBox(height: AppSpace.xl),
          // The text, in a box without a title; it scrolls when it is long.
          Expanded(
            child: a.description.isEmpty
                ? const SizedBox.shrink()
                : GlassCard(
                    padding: EdgeInsets.zero,
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpace.lg),
                        child: Text(a.description, style: const TextStyle(fontSize: AppFont.bodyL, height: AppLine.relaxed)),
                      ),
                    ),
                  ),
          ),
          // The voice note in its own box.
          if (a.voicePath != null) ...[
            const SizedBox(height: AppSpace.lg),
            GlassCard(padding: const EdgeInsets.all(AppSpace.lg), child: VoicePlayer(path: a.voicePath!, durationMs: a.voiceMs)),
          ],
          if (item.files.isNotEmpty) ...[
            SectionLabel(l.filesCaps, padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.lg, AppSpace.xs, AppSpace.sm)),
            for (final f in item.files.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.sm),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.md)), child: Icon(f.isImage ? Lu.image : Lu.file, size: AppIcon.md, color: p.primary)),
                    title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w500)),
                    trailing: Icon(Lu.chevronRight, color: p.text2),
                    onTap: () => openActivityFile(ctx, f),
                  ),
                ),
              ),
          ],
          const SizedBox(height: AppSpace.lg),
          PillButton(label: item.type == ActivityType.note && !isAttachmentOnly(item) ? l.openNoteBtn : l.openActivityBtn, icon: Lu.pencil, onPressed: () => Navigator.of(ctx).pop(true)),
        ]),
      );
    },
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
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.delete, onPressed: () => Navigator.of(ctx).pop(true), danger: true),
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
            PageHeader(
 title: activityTypeLabel(l, item.type),

 actions: [GlassIconButton(icon: Lu.pencil, onHeader: true, onTap: _edit)],
 ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.lg, AppSpace.xl, AppSpace.x5), children: [
                Text(item.type == ActivityType.note && a.title.isNotEmpty ? a.title : activityHeadline(l, a),
                    style: TextStyle(fontSize: AppFont.display, fontWeight: FontWeight.w700, color: p.text)),
                const SizedBox(height: AppSpace.sm),
                Row(children: [
                  Icon(Lu.user, size: AppIcon.md, color: p.text2),
                  const SizedBox(width: AppSpace.sm),
                  Flexible(child: Text([if (contact != null) contact, formatWhen(context, a.occurredAt)].join('  ·  '), style: TextStyle(color: p.text2, fontSize: AppFont.label))),
                ]),
                if (item.outcome != null) ...[
                  const SizedBox(height: AppSpace.md),
                  Align(alignment: AlignmentDirectional.centerStart, child: TagPill(outcomeLabel(l, item.outcome!), large: true)),
                ],
                if (a.place.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.lg),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: a.mapLink.isEmpty ? null : () => _openMap(a.mapLink),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.lg),
                          child: Row(children: [
                            Icon(Lu.mapPin, color: p.primary),
                            const SizedBox(width: AppSpace.md),
                            Expanded(child: Text(a.place, style: const TextStyle(fontSize: AppFont.label))),
                            if (a.mapLink.isNotEmpty) Text(l.actionMap, style: TextStyle(color: p.primary, fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ],
                if (a.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.lg),
                  GlassCard(padding: const EdgeInsets.all(AppSpace.lg), child: Text(a.description, style: const TextStyle(fontSize: AppFont.label, height: AppLine.relaxed))),
                ],
                if (a.voicePath != null) ...[
                  SectionLabel(l.voiceNote),
                  GlassCard(padding: const EdgeInsets.all(AppSpace.md), child: VoicePlayer(path: a.voicePath!, durationMs: a.voiceMs)),
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
                              padding: const EdgeInsets.all(AppSpace.md),
                              child: Row(children: [
                                Container(
                                  width: 40,
                                  height: AppControl.md,
                                  decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
                                  child: Icon(f.isImage ? Lu.image : Lu.file, color: p.onPrimaryContainer),
                                ),
                                const SizedBox(width: AppSpace.md),
                                Expanded(child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w500))),
                              ]),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpace.xl),
                Row(children: [
                  Expanded(child: PillButton(label: l.delete, icon: Lu.trash2, outlined: true, danger: true, height: AppControl.lg, onPressed: _delete)),
                  const SizedBox(width: AppSpace.md),
                  Expanded(child: PillButton(label: l.edit, icon: Lu.pencil, height: AppControl.lg, onPressed: _edit)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
