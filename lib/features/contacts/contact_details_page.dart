import 'dart:io' show File;
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
import '../activities/contact_picker.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../settings/settings_widgets.dart' show ScrollSegControl;
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
import 'companies_page.dart' show CompanyPage;
import '../../core/text_normalize.dart';
import 'contact_form_page.dart';
import 'contact_quick_actions.dart' show pickPhone, phoneLine;
import '../../theme/flag_view.dart';
import '../../shared/ds.dart';
import 'contact_widgets.dart';
import 'phone_book_export.dart';
import '../../theme/tokens.dart';
import '../../theme/lucide.dart';
import '../../shared/scroll_fab.dart';

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
  List<ScheduleItem> _upcomingItems = const [];
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
    final deals = await widget.deals?.listDeals(contactId: widget.id, withColleagues: true) ?? const <DealItem>[];
    final open = deals.where((d) => d.isOpen).toList();
    final acts = widget.activities;
    final files = acts == null ? 0 : (await acts.filesOfContact(widget.id)).length;
    final lastList = acts == null ? const <ActivityItem>[] : await acts.list(contactId: widget.id, limit: 1);
    if (!mounted) return;
    setState(() {
      // Deals, tasks and meetings of this contact also show in its Timeline, so it reloads too.
      _activityToken++;
      _nFiles = files;
      _lastType = lastList.isEmpty ? null : lastList.first.type;
      _overdueItem = overdue.isEmpty ? null : overdue.first;
      _upcomingItems = (List<ScheduleItem>.of(upcoming)..sort((a, b) => a.at.compareTo(b.at))).where((i) => !i.at.isBefore(DateTime(now.year, now.month, now.day))).toList();
      _nSchedule = upcoming.length + overdue.length;
      _nDeals = open.length;
      _stageName = open.isEmpty ? null : stageLabel(AppLocalizations.of(context), open.first.stage);
    });
  }

  /// Opens the list of every contact of this company.
  Future<void> _openCompany(String company) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CompanyPage(
        repo: widget.repo, activities: widget.activities, schedule: widget.schedule, deals: widget.deals, fields: widget.fields,
        companyKey: normalizeText(company),
      ),
    ));
    if (mounted) await _loadExtras();
  }

  /// "today", "yesterday", "tomorrow", or a short date.
  String _relDay(AppLocalizations l, DateTime d) {
    final n = dayOnly(d).difference(dayOnly(DateTime.now())).inDays;
    if (n == 0) return l.relToday;
    if (n == -1) return l.relYesterday;
    if (n == 1) return l.relTomorrow;
    return formatDayShort(context, d);
  }

  String _capFirst(String t) => t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}';

  /// Upcoming items sheet (design CS10): the contact's next tasks, meetings and events.
  Future<void> _showUpcoming(ContactSummary s) async {
    final l = AppLocalizations.of(context);
    final items = _upcomingItems;
    final picked = await showGlassSheet<ScheduleItem>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SheetTitle(l.upcomingCount(items.length), bottom: 2),
        Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.sm), child: Text(s.fullName, style: TextStyle(color: ctx.palette.text2, fontSize: AppFont.subtitle, height: AppLine.normal))),
        Flexible(
          child: SingleChildScrollView(
            child: Column(children: [
              for (var k = 0; k < items.length; k++)
                SheetItem(
                  first: k == 0,
                  icon: switch (items[k].kind) {
                    ScheduleKind.task => Lu.circleCheck,
                    ScheduleKind.meeting => Lu.usersRound,
                    ScheduleKind.event => Lu.gift,
                  },
                  title: items[k].title,
                  subtitle: [
                    _capFirst(_relDay(l, items[k].at)),
                    if (items[k].kind == ScheduleKind.event || !items[k].hasTime) l.allDay else formatClock(ctx, items[k].at),
                    if (items[k].kind == ScheduleKind.task && items[k].priority == Priority.high) priorityLabel(l, Priority.high),
                  ].join(' · '),
                  onTap: () => Navigator.of(ctx).pop(items[k]),
                ),
            ]),
          ),
        ),
      ]),
    );
    if (picked == null || !mounted || widget.schedule == null) return;
    await openScheduleItem(context, item: picked, schedule: widget.schedule!, contacts: widget.repo);
    if (mounted) _loadExtras();
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
    final auto = _statusText(l, c);
    final res = await showGlassSheet<String>(
      context,
      builder: (ctx) => SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SheetTitle(l.cstatSheetTitle),
          Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, 0, AppSpace.xs, AppSpace.md), child: Text(l.cstatSheetSub, style: TextStyle(fontSize: AppFont.body, height: AppLine.airy, color: ctx.palette.text2))),
          GlassField(controller: ctrl, autofocus: true, maxLength: 80, maxLines: 3, label: l.cstatSheetTitle),
          Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.sm, AppSpace.xs, AppSpace.md), child: Text(l.cstatAutoText(auto), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: ctx.palette.text2))),
          SheetButtons(
            secondary: l.cstatReset,
            onSecondary: () => Navigator.of(ctx).pop(''),
            primary: l.save,
            onPrimary: () => Navigator.of(ctx).pop(ctrl.text),
            secondaryFlex: 175,
            primaryFlex: 173,
          ),
        ]),
      ),
    );
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
      builder: (_) => DealFormPage(deals: d, contacts: widget.repo, fields: widget.fields, contactId: widget.id),
    ));
    if (id != null && id > 0) messenger.showSnackBar(SnackBar(content: Text(l.dealSaved)));
  }

  Future<void> _logActivity({ActivityType type = ActivityType.call}) async {
    final acts = widget.activities;
    if (acts == null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = await Navigator.of(context).push<int>(MaterialPageRoute(
      builder: (_) => LogActivityPage(activities: acts, contacts: widget.repo, contactId: widget.id, schedule: widget.schedule, initialType: type),
    ));
    if (id == null || !mounted) return;
    setState(() => _activityToken++);
    _reload();
    if (id > 0) messenger.showSnackBar(SnackBar(content: Text(l.activitySaved)));
  }

  Future<void> _menuAction(ContactSummary s, String v) async {
    if (!mounted) return;
    switch (v) {
      case 'edit':
        await _edit();
      case 'share':
        await showShareSheet(context, s);
      case 'phonebook':
        await saveContactsToPhoneBook(context, [s]);
      case 'merge':
        await _mergeWith(s);
      case 'delete':
        await _delete();
    }
  }

  Future<void> _mergeWith(ContactSummary s) async {
    final l = AppLocalizations.of(context);
    final other = await pickContact(context, widget.repo);
    if (other == null || other.id == null || other.id == widget.id || !mounted) return;
    final ok = await showSheetDialog<bool>(
      context: context,
      builder: (ctx) => SheetDialog(
        title: Text(l.mergeTitle),
        content: Text(l.mergeOneBody(other.name, s.fullName)),
        actions: [
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.mergeAction, onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (ok != true) return;
    final snap = await widget.repo.merge(widget.id, [other.id!]);
    if (!mounted) return;
    _reload();
    if (snap != null) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(
        content: Text(l.dupMerged(other.name)),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
            label: l.undo,
            onPressed: () async {
              await widget.repo.undoMerge(snap);
              if (mounted) _reload();
            }),
      ));
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final ok = await showSheetDialog<bool>(
      context: context,
      builder: (ctx) => SheetDialog(
        title: Text(l.deleteTitle),
        content: Text(l.deleteBody),
        actions: [
          DialogCancel(l.cancel, onPressed: () => Navigator.of(ctx).pop(false)),
          DialogConfirm(l.delete, onPressed: () => Navigator.of(ctx).pop(true), danger: true),
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
    final l = AppLocalizations.of(context);
    final picked = await pickPhone(context, s, title: l.callTitle(s.fullName), icon: Lu.phone);
    if (picked != null) _open(_tel(picked));
  }

  Future<void> _whatsApp(ContactSummary s) async {
    final l = AppLocalizations.of(context);
    final picked = await pickPhone(context, s, title: l.whatsAppTitle(s.fullName), icon: Lu.messageSquare, whatsApp: true);
    if (picked != null) _open(_wa(picked));
  }

  @override
  Widget build(BuildContext context) => FabScope(child: Builder(builder: _buildScreen));

  Widget _buildScreen(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: widget.navBar?.call(context),
      floatingActionButton: ExpandingFab(onPressed: _add, label: widget.schedule == null ? l.logActivity : l.add),
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
      padding: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, 0),
      square: true,
      child: Row(children: [
        GlassIconButton(
          icon: Lu.chevronLeft,
          onHeader: true,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: AnimatedOpacity(
            opacity: _collapsed ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Row(children: [
              if (s.contact.photoPath != null && s.contact.photoPath!.isNotEmpty && File(s.contact.photoPath!).existsSync()) ...[
                ContactAvatar(summary: s, size: 40, showBadges: false),
                const SizedBox(width: AppSpace.md),
              ],
              Expanded(
                child: Text(s.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: AppFont.subtitle, fontWeight: FontWeight.w600, height: AppLine.tight, color: p.onHeader)),
              ),
            ]),
          ),
        ),
        if (_collapsed && s.phones.isNotEmpty) ...[
          GlassIconButton(icon: Lu.phone, onHeader: true, onTap: () => _call(s)),
          const SizedBox(width: AppSpace.sm),
        ],
        HeaderMenu<String>(
          onSelected: (v) => _menuAction(s, v),
          actions: [
            MenuAction('edit', Lu.pencil, AppLocalizations.of(context).edit),
            MenuAction('share', Lu.share, AppLocalizations.of(context).bulkShare),
            if (s.phones.isNotEmpty) MenuAction('phonebook', Lu.contact, AppLocalizations.of(context).saveToPhoneBook),
            MenuAction('merge', Lu.merge, AppLocalizations.of(context).mergeWithOther),
            MenuAction('delete', Lu.trash2, AppLocalizations.of(context).delete, danger: true),
          ],
        ),
      ]),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    final p = context.palette;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
        child: GlassCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
              child: Column(children: [
                Icon(icon, color: p.primary, size: AppIcon.lg),
                const SizedBox(height: AppSpace.xs),
                Text(label, style: const TextStyle(fontSize: AppFont.badge, height: AppLine.normal, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _soon(AppLocalizations l, YoncaPalette p, String text) => EmptyState(icon: Lu.history, title: text);

  Widget _body(BuildContext context, AppLocalizations l, ContactSummary s) {
    final p = context.palette;
    final c = s.contact;
    final rating = ratingFromName(c.rating);
    final subtitle = s.isIncomplete
        ? l.noNameYet
        : [c.jobTitle, c.department].where((t) => t.isNotEmpty && t != s.displayName).join(' · ');
    final company = s.isIncomplete || c.company.trim().isEmpty || c.company == s.displayName ? '' : c.company.trim();
    final tabNames = [
      l.tabTimeline,
      _nSchedule > 0 ? '${l.tabSchedule} $_nSchedule' : l.tabSchedule,
      _nDeals > 0 ? '${l.navDeals} $_nDeals' : l.navDeals,
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
                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, 0),
                  decoration: BoxDecoration(color: p.header),
                  child: Column(children: [
                  // The photo is shown large; a contact without one has no placeholder here.
                  if (c.photoPath != null && c.photoPath!.isNotEmpty && File(c.photoPath!).existsSync()) ...[
                    ContactAvatar(summary: s, size: AppControl.hero * 2, fontSize: AppFont.pageTitle, showBadges: false, onHeader: true),
                    const SizedBox(height: AppSpace.md),
                  ],
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: [if (c.prefix.isNotEmpty) c.prefix, s.displayName, if (c.suffix.isNotEmpty) c.suffix].join(' ')),
                      if (c.nickname.isNotEmpty)
                        TextSpan(text: ' · ${c.nickname}', style: TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w400, color: p.text2)),
                    ]),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: AppFont.pageTitle, height: AppLine.normal, fontWeight: FontWeight.w600, color: p.onHeader),
                  ),
                  if (c.phoneticName.isNotEmpty)
                    Text(c.phoneticName, textAlign: TextAlign.center, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, color: p.text2)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, color: p.text2)),
                  if (company.isNotEmpty)
                    InkWell(
                      onTap: () => _openCompany(company),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Lu.building2, size: AppIcon.sm, color: p.primary),
                          const SizedBox(width: AppSpace.xs),
                          Flexible(child: Text(company, textAlign: TextAlign.center, style: TextStyle(fontSize: AppFont.body, height: AppLine.normal, fontWeight: FontWeight.w500, color: p.primary))),
                        ]),
                      ),
                    ),
                  if (s.roles.isNotEmpty || rating != Rating.none)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.md),
                      child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
                        for (final r in s.roles) TagPill(roleLabel(l, r), large: true),
                        if (rating != Rating.none)
                          TagPill(ratingLabel(l, rating), icon: ratingIcon(rating), large: true),
                      ]),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.lg, AppSpace.lg, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    if (s.whatsAppPhones.isNotEmpty) _actionButton(Lu.messageSquare, l.actionWhatsApp, () => _whatsApp(s)),
                    if (s.phones.isNotEmpty) _actionButton(Lu.phone, l.actionCall, () => _call(s)),
                    if (s.emails.isNotEmpty)
                      _actionButton(Lu.mail, l.actionEmail,
                          () => _openEntry(s.emails, l.emailTitle(s.fullName), Lu.mail)),
                    if (s.addresses.isNotEmpty)
                      _actionButton(Lu.mapPin, l.actionMap,
                          () => _openEntry(s.addresses, l.mapTitle, Lu.mapPin)),
                  ]),
                  const SizedBox(height: AppSpace.md),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        onTap: () => _editStatus(c),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_statusText(l, c), style: const TextStyle(fontSize: AppFont.body, height: AppLine.snug, fontWeight: FontWeight.w500)),
                            Text(c.statusOverride == null ? l.cstatAuto : l.cstatEdited, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  if (overdueItem != null) ...[
                    const SizedBox(height: AppSpace.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
                      decoration: BoxDecoration(color: p.errorContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
                      child: Row(children: [
                        Icon(Lu.triangleAlert, size: AppIcon.lg, color: p.onErrorContainer),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.cstatOverdue(overdueItem.title), style: TextStyle(fontSize: AppFont.body, height: AppLine.snug, fontWeight: FontWeight.w500, color: p.onErrorContainer)),
                            Text(l.cstatDue('${_relDay(l, overdueItem.at)}, ${formatClock(context, overdueItem.at)}'),
                                style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.onErrorContainer)),
                          ]),
                        ),
                      ]),
                    ),
                  ],
                  if (_upcomingItems.isNotEmpty) ...[
                    const SizedBox(height: AppSpace.md),
                    _NextUpCard(
                      item: _upcomingItems.first,
                      more: _upcomingItems.length - 1,
                      when: _capFirst('${_relDay(l, _upcomingItems.first.at)}, ${_upcomingItems.first.kind == ScheduleKind.event || !_upcomingItems.first.hasTime ? l.allDay : formatClock(context, _upcomingItems.first.at)}'),
                      onTap: () => _showUpcoming(s),
                    ),
                  ],
                  if (needsCompleting) ...[
                    const SizedBox(height: AppSpace.lg),
                    GlassCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Icon(Lu.info, color: p.primary, size: AppIcon.md),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(child: Text(l.completeContact, style: const TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w600))),
                        ]),
                        const SizedBox(height: AppSpace.sm),
                        Text(c.temporaryNote.trim().isNotEmpty ? c.temporaryNote : l.completeContactBody,
                            style: TextStyle(color: p.text2, fontSize: AppFont.label)),
                        const SizedBox(height: AppSpace.md),
                        PillButton(label: l.complete, height: AppControl.lg, onPressed: _edit),
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
              ContactFilesTab(
                activities: widget.activities!,
                contacts: widget.repo,
                contactId: widget.id,
                reloadToken: _activityToken,
                onNote: () => _logActivity(type: ActivityType.note),
                onChanged: () {
                  setState(() => _activityToken++);
                  _reload();
                },
              )
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

/// "Next up" card under the status cards (design CS19): the nearest upcoming item, tap for the full list.
class _NextUpCard extends StatelessWidget {
  const _NextUpCard({required this.item, required this.more, required this.when, required this.onTap});
  final ScheduleItem item;
  final int more;
  final String when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
            child: Row(children: [
              Container(
                width: 36,
                height: AppControl.md,
                decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(AppRadius.md)),
                child: Icon(Lu.calendarDays, size: AppIcon.md, color: p.primary),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.nextUp, style: TextStyle(fontSize: AppFont.badge, height: AppLine.snug, fontWeight: FontWeight.w500, color: p.text2)),
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppFont.body, height: AppLine.snug, fontWeight: FontWeight.w500)),
                  Text(more > 0 ? '$when · ${l.nextMore(more)}' : when, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
                ]),
              ),
              Icon(Lu.chevronRight, color: p.text2),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TabChipsHeader extends SliverPersistentHeaderDelegate {
  _TabChipsHeader({required this.names, required this.selected, required this.onSelect, required this.color});
  final List<String> names;
  final int selected;
  final ValueChanged<int> onSelect;
  final Color color;

  @override
  double get minExtent => AppControl.lg + AppSpace.xxl;
  @override
  double get maxExtent => AppControl.lg + AppSpace.xxl;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(color: color, child: SizedBox(height: maxExtent, child: Padding(padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.md, AppSpace.xl, AppSpace.md), child: ScrollSegControl(labels: names, selected: selected, onSelect: onSelect))));
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
    this.flagCode,
  });
  final String? flagCode;
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.lg),
        child: Row(children: [
          IconTile(
            icon: icon,
            background: p.primaryContainer,
            color: p.onPrimaryContainer,
            child: flagCode != null ? FlagView.dial(flagCode!) : null,
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  textDirection: ltrTitle ? TextDirection.ltr : null,
                  style: const TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w500, height: AppLine.normal)),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(subtitle!, style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
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
          if (i > 0) Divider(height: 1, thickness: 1, indent: AppSpace.lg, endIndent: AppSpace.lg, color: p.separator),
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
      padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.fabClear),
      children: [
        if (c.requirements.isNotEmpty) ...[
          SectionLabel(l.fieldRequirements, padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.sm, AppSpace.xs, AppSpace.sm)),
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
          SectionLabel(l.fieldPhone, padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.lg, AppSpace.xs, AppSpace.sm)),
          _card([
            for (final ph in s.phones)
              _InfoRow(
                icon: Lu.phone,
                title: phoneLine(ph),
                flagCode: ph.countryCode,
                subtitle: phoneLabelText(l, ph.label),
                ltrTitle: true,
                onTap: () => widget.onOpen(widget.tel(ph)),
                trailing: ph.label == 'landline'
                    ? null
                    : IconButton(
                        onPressed: () => widget.onOpen(widget.wa(ph)),
                        icon: Icon(Lu.messageSquare, color: p.text),
                      ),
              ),
          ]),
        ],
        for (final (kind, title, icon) in [
          ('email', l.fieldEmail, Lu.mail),
          ('address', l.fieldAddress, Lu.mapPin),
          ('website', l.fieldWebsite, Lu.globe),
          ('relation', l.fieldRelation, Lu.users),
          ('im', l.fieldIm, Lu.messagesSquare),
        ])
          if (s.entries.any((e) => e.kind == kind)) ...[
            SectionLabel(title, padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.lg, AppSpace.xs, AppSpace.sm)),
            _card([
              for (final e in s.entries.where((e) => e.kind == kind))
                _InfoRow(
                  icon: icon,
                  title: e.value,
                  subtitle: kind == 'address'
                      ? '${phoneLabelText(l, e.label)} · ${l.opensInMaps}'
                      : entryLabelText(l, kind, e.label),
                  ltrTitle: kind != 'address' && kind != 'relation',
                  onTap: kind == 'relation' || kind == 'im' ? null : () => widget.onOpen(widget.entryUri(e)),
                ),
            ]),
          ],
        if (s.tags.isNotEmpty) ...[
          SectionLabel(l.fieldTags, padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.lg, AppSpace.xs, AppSpace.sm)),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final t in s.tags) PillChip(label: t.name)]),
        ],
        if (s.events.isNotEmpty) ...[
          SectionLabel(l.fieldEvents, padding: const EdgeInsets.fromLTRB(AppSpace.xs, AppSpace.lg, AppSpace.xs, AppSpace.sm)),
          _card([
            for (final e in s.events)
              _InfoRow(
                icon: Lu.calendarDays,
                title: e.title,
                subtitle: dfmt(DateFormat.yMMMd(Localizations.localeOf(context).toString()), e.date) +
                    (e.yearly ? ' · ${l.eventYearly}' : ''),
              ),
          ]),
        ],
        if (widget.extra != null) widget.extra!,
      ],
    );
  }
}
