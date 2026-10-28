import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../../core/format.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/text_normalize.dart';
import '../../data/app_database.dart';
import '../../data/activities_repository.dart';
import '../../domain/activity_models.dart';
import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../activities/activity_feed.dart';
import '../activities/log_activity_page.dart';
import '../../data/schedule_repository.dart';
import '../schedule/contact_schedule_tab.dart';
import '../../data/deals_repository.dart';
import '../deals/contact_deals_tab.dart';
import '../../data/fields_repository.dart';
import '../../domain/field_models.dart';
import '../fields/field_values.dart';
import '../sharing/share_helpers.dart';
import '../deals/deal_form_page.dart';
import '../schedule/schedule_widgets.dart';
import '../schedule/schedule_labels.dart';
import '../../domain/schedule_models.dart';
import '../../domain/deal_models.dart';
import '../deals/deal_widgets.dart';
import 'contact_form_page.dart';
import 'contact_widgets.dart';

/// Contact details (design S08): top bar, hero header, action row, pinned tab chips, tab content.
/// Only the Details tab has content so far; the others arrive with later milestones.
class ContactDetailsPage extends StatefulWidget {
  const ContactDetailsPage({super.key, required this.repo, required this.id, this.activities, this.schedule, this.deals, this.fields, this.navBar});

  /// The app's bottom bar, kept visible on this page like in the design.
  final Widget Function(BuildContext context)? navBar;
  final ContactsRepository repo;
  final ActivitiesRepository? activities;
  final ScheduleRepository? schedule;
  final DealsRepository? deals;
  final FieldsRepository? fields;
  final int id;

  @override
  State<ContactDetailsPage> createState() => _ContactDetailsPageState();
}

class _ContactDetailsPageState extends State<ContactDetailsPage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _callPending = false;
  late Future<ContactSummary?> _future = widget.repo.get(widget.id);
  late final TabController _tabs = TabController(length: 5, vsync: this, initialIndex: 0);
  final _scroll = ScrollController();
  bool _collapsed = false;
  int _activityToken = 0;
  ScheduleItem? _overdueItem;
  String? _stageName;
  int _nSchedule = 0;
  int _nFiles = 0;
  ActivityType? _lastType;
  int _nDeals = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs.addListener(() => setState(() {}));
    widget.schedule?.revision.addListener(_loadExtras);
    widget.deals?.revision.addListener(_loadExtras);
    _loadExtras();
    _scroll.addListener(() {
      final c = _scroll.hasClients && _scroll.offset > 150;
      if (c != _collapsed) setState(() => _collapsed = c);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.schedule?.revision.removeListener(_loadExtras);
    widget.deals?.revision.removeListener(_loadExtras);
    _tabs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Back from the phone app after a call: offer to log it for 10 seconds.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_callPending) return;
    _callPending = false;
    if (!mounted || widget.activities == null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(l.callBarPrompt),
      duration: const Duration(seconds: 10),
      action: SnackBarAction(label: l.callBarLog, onPressed: _logActivity),
    ));
  }

  void _reload() {
    setState(() {
      _future = widget.repo.get(widget.id);
    });
    _loadExtras();
  }

  /// Overdue task, current deal stage and tab counts for the status line, red card and tab chips.
  Future<void> _loadExtras() async {
    final now = DateTime.now();
    final overdue = await widget.schedule?.overdueTasks(contactId: widget.id) ?? const <ScheduleItem>[];
    final upcoming = await widget.schedule?.itemsBetween(now, now.add(const Duration(days: 730)), contactId: widget.id, includeDone: false) ?? const <ScheduleItem>[];
    final deals = await widget.deals?.listDeals(contactId: widget.id) ?? const <DealItem>[];
    final open = deals.where((d) => d.isOpen).toList();
    final acts = widget.activities;
    final files = acts == null ? 0 : (await acts.filesOfContact(widget.id)).length;
    final lastList = acts == null ? const <ActivityItem>[] : await acts.list(contactId: widget.id, limit: 1);
    if (!mounted) return;
    setState(() {
      _nFiles = files;
      _lastType = lastList.isEmpty ? null : lastList.first.type;
      _overdueItem = overdue.isEmpty ? null : overdue.first;
      _nSchedule = upcoming.length + overdue.length;
      _nDeals = open.length;
      _stageName = open.isEmpty ? null : stageLabel(AppLocalizations.of(context), open.first.stage);
    });
  }

  /// "today", "yesterday", "tomorrow", or a short date.
  String _relDay(AppLocalizations l, DateTime d) {
    final n = dayOnly(d).difference(dayOnly(DateTime.now())).inDays;
    if (n == 0) return l.relToday;
    if (n == -1) return l.relYesterday;
    if (n == 1) return l.relTomorrow;
    return formatDayShort(context, d);
  }

  String _lastText(AppLocalizations l, String date) => switch (_lastType) {
        ActivityType.call => l.cstatLastCall(date),
        ActivityType.visit => l.cstatLastVisit(date),
        ActivityType.message => l.cstatLastMessage(date),
        _ => l.cstatLast(date),
      };

  String _statusText(AppLocalizations l, Contact c) {
    final o = c.statusOverride;
    if (o != null && o.trim().isNotEmpty) return o;
    final last = c.lastActivityAt;
    final parts = [
      if (_stageName != null) _stageName!,
      if (last != null) _lastText(l, dfmt(DateFormat('d MMM', Localizations.localeOf(context).toString()), last)),
    ];
    return parts.isEmpty ? l.cstatNone : parts.join(', ');
  }

  Future<void> _editStatus(Contact c) async {
    final l = AppLocalizations.of(context);
    final ctrl = TextEditingController(text: c.statusOverride ?? _statusText(l, c));
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.cstatEditTitle),
        content: GlassField(controller: ctrl, autofocus: true, maxLength: 80, label: l.cstatEditTitle),
        actions: [
          if (c.statusOverride != null) TextButton(onPressed: () => Navigator.of(ctx).pop(''), child: Text(l.cstatReset)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: Text(l.save)),
        ],
      ),
    );
    ctrl.dispose();
    if (res == null) return;
    await widget.repo.setStatusOverride(widget.id, res);
    if (mounted) _reload();
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => ContactFormPage(repo: widget.repo, id: widget.id)),
    );
    if (saved != null && mounted) _reload();
  }

  Future<void> _add() async {
    final s = widget.schedule;
    if (s == null) return _logActivity();
    await showAddSheet(
      context,
      schedule: s,
      contacts: widget.repo,
      contactId: widget.id,
      onLogActivity: widget.activities == null ? null : _logActivity,
      onNewDeal: widget.deals == null ? null : _newDeal,
    );
  }

  Future<void> _newDeal() async {
    final d = widget.deals;
    if (d == null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = await Navigator.of(context).push<int>(MaterialPageRoute(
      builder: (_) => DealFormPage(deals: d, contacts: widget.repo, contactId: widget.id),
    ));
    if (id != null && id > 0) messenger.showSnackBar(SnackBar(content: Text(l.dealSaved)));
  }

  Future<void> _logActivity() async {
    final acts = widget.activities;
    if (acts == null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = await Navigator.of(context).push<int>(MaterialPageRoute(
      builder: (_) => LogActivityPage(activities: acts, contacts: widget.repo, contactId: widget.id, schedule: widget.schedule),
    ));
    if (id == null || !mounted) return;
    setState(() => _activityToken++);
    _reload();
    if (id > 0) messenger.showSnackBar(SnackBar(content: Text(l.activitySaved)));
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteTitle),
        content: Text(l.deleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok == true) {
      await widget.repo.delete(widget.id);
      nav.pop();
    }
  }

  Future<void> _open(Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).launchFailed;
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    } else if (uri.scheme == 'tel') {
      _callPending = true;
    }
  }

  Uri _tel(ContactPhone p) => Uri(scheme: 'tel', path: '${p.countryCode}${p.number}'.replaceAll(' ', ''));
  Uri _wa(ContactPhone p) => Uri.parse('https://wa.me/${normalizePhone(p.countryCode, p.number)}');

  /// What tapping an email, website or address opens. An address with a map link opens that link.
  Uri entryUri(ContactEntry e) {
    // Any link works (Google Maps, Apple Maps, Waze, OpenStreetMap, geo:, ...); without a scheme https is assumed.
    String web(String v) => RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:(//|[^0-9/])').hasMatch(v) ? v : 'https://$v';
    return switch (e.kind) {
      'email' => Uri(scheme: 'mailto', path: e.value),
      'website' => Uri.parse(web(e.value)),
      _ => e.mapLink.trim().isNotEmpty
          ? Uri.parse(web(e.mapLink.trim()))
          : Uri.parse('geo:0,0?q=${Uri.encodeComponent(e.value)}'),
    };
  }

  /// Opens the only entry directly, or asks which one when there are several.
  Future<void> _openEntry(List<ContactEntry> list, String title, IconData icon) async {
    if (list.length == 1) {
      _open(entryUri(list.first));
      return;
    }
    final l = AppLocalizations.of(context);
    final picked = await showGlassSheet<ContactEntry>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(title),
        for (var i = 0; i < list.length; i++)
          SheetItem(
            first: i == 0,
            icon: icon,
            iconSize: 40,
            title: list[i].value,
            subtitle: list[i].kind == 'address' ? null : phoneLabelText(l, list[i].label),
            ltrTitle: list[i].kind != 'address',
            onTap: () => Navigator.of(ctx).pop(list[i]),
          ),
      ]),
    );
    if (picked != null) _open(entryUri(picked));
  }

  Future<void> _call(ContactSummary s) async {
    if (s.phones.length == 1) {
      _open(_tel(s.phones.first));
      return;
    }
    final l = AppLocalizations.of(context);
    final picked = await showGlassSheet<ContactPhone>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(l.callTitle(s.displayName)),
        for (var i = 0; i < s.phones.length; i++)
          SheetItem(
            first: i == 0,
            icon: Icons.phone_outlined,
            title: '${s.phones[i].countryCode} ${s.phones[i].number}',
            subtitle: phoneLabelText(l, s.phones[i].label),
            ltrTitle: true,
            onTap: () => Navigator.of(ctx).pop(s.phones[i]),
          ),
      ]),
    );
    if (picked != null) _open(_tel(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: widget.navBar?.call(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(widget.schedule == null ? l.logActivity : l.add),
      ),
      body: GlassBackdrop(
        child: FutureBuilder<ContactSummary?>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return SafeArea(child: ErrorView(onRetry: _reload));
            if (!snap.hasData) return const SafeArea(child: LoadingView());
            return _body(context, l, snap.data!);
          },
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, AppLocalizations l, ContactSummary s) {
    final p = context.palette;
    return HeaderBand(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      square: true,
      child: Row(children: [
        GlassIconButton(
          icon: Icons.chevron_left,
          onHeader: true,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: AnimatedOpacity(
            opacity: _collapsed ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Row(children: [
              ContactAvatar(summary: s, size: 40, showBadges: false),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.25, color: p.onHeader)),
              ),
            ]),
          ),
        ),
        if (_collapsed && s.phones.isNotEmpty) ...[
          GlassIconButton(icon: Icons.call_outlined, onHeader: true, onTap: () => _call(s)),
          const SizedBox(width: 8),
        ],
        PopupMenuButton<String>(
          color: context.palette.sheet,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onSelected: (v) => v == 'edit' ? _edit() : (v == 'share' ? showShareSheet(context, s) : _delete()),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(l.edit)),
            PopupMenuItem(value: 'share', child: Text(l.bulkShare)),
            PopupMenuItem(value: 'delete', child: Text(l.delete)),
          ],
          child: const IgnorePointer(child: GlassIconButton(icon: Icons.more_vert, onTap: null, onHeader: true)),
        ),
      ]),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    final p = context.palette;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GlassCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(children: [
                Icon(icon, color: p.primary, size: 22),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 12, height: 16.8 / 12, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _soon(AppLocalizations l, YoncaPalette p, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: p.text2)),
        ),
      );

  Widget _body(BuildContext context, AppLocalizations l, ContactSummary s) {
    final p = context.palette;
    final c = s.contact;
    final rating = ratingFromName(c.rating);
    final waPhone = s.phones.where((x) => x.isWhatsApp).firstOrNull;
    final subtitle = s.isIncomplete
        ? l.noNameYet
        : [c.jobTitle, c.department, c.company].where((t) => t.isNotEmpty && t != s.displayName).join(' · ');
    final tabNames = [
      l.tabTimeline,
      _nSchedule > 0 ? '${l.tabSchedule} $_nSchedule' : l.tabSchedule,
      _nDeals > 0 ? '${l.tabDeals} $_nDeals' : l.tabDeals,
      _nFiles > 0 ? '${l.tabFiles} $_nFiles' : l.tabFiles,
      l.detailsTitle,
    ];
    final overdueItem = _overdueItem;
    final needsCompleting = s.isIncomplete || c.temporaryNote.trim().isNotEmpty;
    return Column(children: [
      _topBar(context, l, s),
      Expanded(
        child: NestedScrollView(
          controller: _scroll,
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Column(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  decoration: BoxDecoration(color: p.header),
                  child: Column(children: [
                  ContactAvatar(summary: s, size: 40, fontSize: 22, showBadges: false, onHeader: true),
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: c.prefix.isEmpty ? s.displayName : '${c.prefix} ${s.displayName}'),
                      if (c.nickname.isNotEmpty)
                        TextSpan(text: ' · ${c.nickname}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: p.text2)),
                    ]),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, height: 31 / 22, fontWeight: FontWeight.w600, color: p.onHeader),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, height: 21 / 15, color: p.text2)),
                  if (s.roles.isNotEmpty || rating != Rating.none)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
                        for (final r in s.roles) TagPill(roleLabel(l, r), large: true),
                        if (rating != Rating.none)
                          TagPill(ratingLabel(l, rating), icon: ratingIcon(rating), large: true),
                      ]),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    if (waPhone != null) _actionButton(Icons.chat_outlined, l.actionWhatsApp, () => _open(_wa(waPhone))),
                    if (s.phones.isNotEmpty) _actionButton(Icons.call_outlined, l.actionCall, () => _call(s)),
                    if (s.emails.isNotEmpty)
                      _actionButton(Icons.email_outlined, l.actionEmail,
                          () => _openEntry(s.emails, l.emailTitle(s.displayName), Icons.email_outlined)),
                    if (s.addresses.isNotEmpty)
                      _actionButton(Icons.place_outlined, l.actionMap,
                          () => _openEntry(s.addresses, l.mapTitle, Icons.place_outlined)),
                  ]),
                  const SizedBox(height: 10),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _editStatus(c),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_statusText(l, c), style: const TextStyle(fontSize: 15, height: 19 / 15, fontWeight: FontWeight.w500)),
                            Text(c.statusOverride == null ? l.cstatAuto : l.cstatEdited, style: TextStyle(fontSize: 12.5, height: 17.5 / 12.5, color: p.text2)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  if (overdueItem != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(color: p.errorContainer, borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        Icon(Icons.warning_amber_rounded, size: 22, color: p.onErrorContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.cstatOverdue(overdueItem.title), style: TextStyle(fontSize: 15, height: 19 / 15, fontWeight: FontWeight.w500, color: p.onErrorContainer)),
                            Text(l.cstatDue('${_relDay(l, overdueItem.at)}, ${formatClock(context, overdueItem.at)}'),
                                style: TextStyle(fontSize: 12.5, height: 17.5 / 12.5, color: p.onErrorContainer)),
                          ]),
                        ),
                      ]),
                    ),
                  ],
                  if (needsCompleting) ...[
                    const SizedBox(height: 14),
                    GlassCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Icon(Icons.info_outline, color: p.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(l.completeContact, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                        ]),
                        const SizedBox(height: 6),
                        Text(c.temporaryNote.trim().isNotEmpty ? c.temporaryNote : l.completeContactBody,
                            style: TextStyle(color: p.text2, fontSize: 14)),
                        const SizedBox(height: 12),
                        PillButton(label: l.complete, height: 48, onPressed: _edit),
                      ]),
                    ),
                  ],
                  ]),
                ),
              ]),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabChipsHeader(
                names: tabNames,
                selected: _tabs.index,
                onSelect: (i) => _tabs.animateTo(i),
                color: p.bg,
              ),
            ),
          ],
          body: TabBarView(controller: _tabs, children: [
            if (widget.activities != null)
              ActivityFeed(
                activities: widget.activities!,
                contacts: widget.repo,
                contactId: widget.id,
                reloadToken: _activityToken,
                onChanged: () {
                  setState(() => _activityToken++);
                  _reload();
                },
              )
            else
              _soon(l, p, l.noActivityYet),
            if (widget.schedule != null)
              ContactScheduleTab(schedule: widget.schedule!, contacts: widget.repo, contactId: widget.id)
            else
              _soon(l, p, l.placeholderSoon),
            if (widget.deals != null)
              ContactDealsTab(deals: widget.deals!, contacts: widget.repo, contactId: widget.id)
            else
              _soon(l, p, l.placeholderSoon),
            if (widget.activities != null)
              ContactFilesTab(activities: widget.activities!, contactId: widget.id, reloadToken: _activityToken)
            else
              _soon(l, p, l.placeholderSoon),
            _DetailsTab(
              summary: s,
              onCall: () => _call(s),
              onOpen: _open,
              wa: _wa,
              tel: _tel,
              entryUri: entryUri,
              extra: widget.fields == null ? null : FieldValuesCard(fields: widget.fields!, scope: FieldScope.contact, ownerId: widget.id),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class _TabChipsHeader extends SliverPersistentHeaderDelegate {
  _TabChipsHeader({required this.names, required this.selected, required this.onSelect, required this.color});
  final List<String> names;
  final int selected;
  final ValueChanged<int> onSelect;
  final Color color;

  @override
  double get minExtent => 66;
  @override
  double get maxExtent => 66;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(color: color, child: SizedBox(height: maxExtent, child: _TabChipsRow(names: names, selected: selected, onSelect: onSelect)));
  }

  @override
  bool shouldRebuild(covariant _TabChipsHeader old) =>
      old.selected != selected || old.color != color || old.names.join() != names.join();
}

/// A list row with the design's square icon (`.ico`), a title, a small line, and an optional trailing widget.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.ltrTitle = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool ltrTitle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: p.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  textDirection: ltrTitle ? TextDirection.ltr : null,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.4)),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(subtitle!, style: TextStyle(fontSize: 13, height: 1.4, color: p.text2)),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}

class _DetailsTab extends StatefulWidget {
  const _DetailsTab({required this.summary, required this.onCall, required this.onOpen, required this.wa, required this.tel, required this.entryUri, this.extra});
  final Widget? extra;
  final ContactSummary summary;
  final VoidCallback onCall;
  final Future<void> Function(Uri) onOpen;
  final Uri Function(ContactPhone) wa;
  final Uri Function(ContactPhone) tel;
  final Uri Function(ContactEntry) entryUri;

  @override
  State<_DetailsTab> createState() => _DetailsTabState();
}

class _DetailsTabState extends State<_DetailsTab> {
  bool _reqOpen = false;

  Widget _card(List<Widget> rows) {
    final p = context.palette;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, indent: 14, endIndent: 14, color: p.separator),
          rows[i],
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final s = widget.summary;
    final c = s.contact;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      children: [
        if (widget.extra != null) widget.extra!,
        if (c.requirements.isNotEmpty) ...[
          SectionLabel(l.fieldRequirements, padding: const EdgeInsets.fromLTRB(4, 8, 4, 8)),
          GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.requirements, maxLines: _reqOpen ? null : 3, overflow: _reqOpen ? null : TextOverflow.ellipsis),
              if (c.requirements.length > 120 || '\n'.allMatches(c.requirements).length >= 2)
                TextButton(
                  onPressed: () => setState(() => _reqOpen = !_reqOpen),
                  child: Text(_reqOpen ? l.showLess : l.showMore),
                ),
            ]),
          ),
        ],
        if (s.phones.isNotEmpty) ...[
          SectionLabel(l.fieldPhone, padding: const EdgeInsets.fromLTRB(4, 16, 4, 8)),
          _card([
            for (final ph in s.phones)
              _InfoRow(
                icon: Icons.phone_outlined,
                title: '${ph.countryCode} ${ph.number}',
                subtitle: phoneLabelText(l, ph.label),
                ltrTitle: true,
                onTap: () => widget.onOpen(widget.tel(ph)),
                trailing: ph.isWhatsApp
                    ? IconButton(
                        onPressed: () => widget.onOpen(widget.wa(ph)),
                        icon: Icon(Icons.chat_outlined, color: p.text),
                      )
                    : null,
              ),
          ]),
        ],
        for (final (kind, title, icon) in [
          ('email', l.fieldEmail, Icons.email_outlined),
          ('address', l.fieldAddress, Icons.place_outlined),
          ('website', l.fieldWebsite, Icons.language),
        ])
          if (s.entries.any((e) => e.kind == kind)) ...[
            SectionLabel(title, padding: const EdgeInsets.fromLTRB(4, 16, 4, 8)),
            _card([
              for (final e in s.entries.where((e) => e.kind == kind))
                _InfoRow(
                  icon: icon,
                  title: e.value,
                  subtitle: kind == 'address'
                      ? '${phoneLabelText(l, e.label)} · ${l.opensInMaps}'
                      : phoneLabelText(l, e.label),
                  ltrTitle: kind != 'address',
                  onTap: () => widget.onOpen(widget.entryUri(e)),
                ),
            ]),
          ],
        if (s.tags.isNotEmpty) ...[
          SectionLabel(l.fieldTags, padding: const EdgeInsets.fromLTRB(4, 16, 4, 8)),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final t in s.tags) PillChip(label: t.name)]),
        ],
        if (s.events.isNotEmpty) ...[
          SectionLabel(l.fieldEvents, padding: const EdgeInsets.fromLTRB(4, 16, 4, 8)),
          _card([
            for (final e in s.events)
              _InfoRow(
                icon: Icons.event_outlined,
                title: e.title,
                subtitle: dfmt(DateFormat.yMMMd(Localizations.localeOf(context).toString()), e.date) +
                    (e.yearly ? ' · ${l.eventYearly}' : ''),
              ),
          ]),
        ],
      ],
    );
  }
}

/// The tab chips in a horizontal list that scrolls to keep the selected chip in view (also when the
/// page is swiped).
class _TabChipsRow extends StatefulWidget {
  const _TabChipsRow({required this.names, required this.selected, required this.onSelect});
  final List<String> names;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  State<_TabChipsRow> createState() => _TabChipsRowState();
}

class _TabChipsRowState extends State<_TabChipsRow> {
  late final List<GlobalKey> _keys = List.generate(widget.names.length, (_) => GlobalKey());
  final _ctl = ScrollController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(covariant _TabChipsRow old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _reveal();
  }

  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[widget.selected].currentContext;
      if (ctx == null) return;
      final ro = ctx.findRenderObject();
      if (ro == null || !_ctl.hasClients) return;
      // Only the chip row scrolls; the page itself must stay where it is.
      _ctl.position.ensureVisible(ro, alignment: .5, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _ctl,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Row(children: [
        for (var i = 0; i < widget.names.length; i++)
          Padding(
            key: _keys[i],
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: PillChip(label: widget.names[i], selected: i == widget.selected, onTap: () => widget.onSelect(i)),
          ),
      ]),
    );
  }
}
