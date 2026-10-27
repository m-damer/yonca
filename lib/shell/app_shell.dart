import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';

import '../app_controller.dart';
import '../data/crash_log.dart';
import '../data/update_service.dart' show appVersion, appBuild;
import '../data/widget_sync.dart';
import 'package:share_plus/share_plus.dart';
import '../features/schedule/alarm_page.dart';
import '../features/schedule/meeting_form_page.dart';
import '../features/schedule/task_form_page.dart';
import '../features/activities/activity_feed.dart';
import '../features/activities/outcome_list_page.dart';
import '../features/contacts/contact_form_page.dart';
import '../features/contacts/contacts_tab.dart';
import '../features/contacts/quick_add_sheet.dart';
import '../features/contacts/tags_page.dart';
import '../features/sharing/qr_generator_page.dart';
import '../features/sharing/share_helpers.dart' show QrShowPage;
import '../features/deals/deals_tab.dart';
import '../features/fields/fields_page.dart';
import '../features/data/data_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/settings_widgets.dart';
import '../features/deals/stages_page.dart';
import '../features/importing/profile_page.dart';
import '../features/home/home_tab.dart';
import '../features/importing/duplicates_page.dart';
import '../features/importing/import_page.dart';
import '../features/importing/scan_page.dart';
import '../features/reports/reports_page.dart';
import '../features/stats/stats_page.dart';
import '../features/schedule/calendar_tab.dart';
import '../features/search/search_page.dart';
import '../features/schedule/schedule_widgets.dart';
import '../l10n/app_localizations.dart';
import '../shared/glass_widgets.dart';
import '../theme/glass.dart';
import '../theme/palette.dart';
import 'bento_nav_bar.dart';

/// Five-tab shell: Home, Contacts, Calendar, Deals, More. Tabs are placeholders until M1+.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});
  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final _contactsKey = GlobalKey<ContactsTabState>();
  final _dealsKey = GlobalKey<DealsTabState>();
  final _homeKey = GlobalKey<HomeTabState>();

  String? _shortcutLang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode;
    if (_shortcutLang == lang) return;
    _shortcutLang = lang;
    _setupShortcuts();
    _syncWidget();
  }

  void _handleAction(String type) {
    if (!mounted) return;
    switch (type) {
      case 'new_contact':
        setState(() => _index = 1);
        _add();
      case 'new_task':
        final repo = widget.controller.contacts;
        final schedule = widget.controller.schedule;
        if (repo != null && schedule != null) showAddSheet(context, schedule: schedule, contacts: repo);
      case 'search':
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SearchPage(controller: widget.controller)));
    }
  }

  StreamSubscription<Uri?>? _widgetClicks;

  @override
  void initState() {
    super.initState();
    _setupWidget();
    widget.controller.alarmRequest.addListener(_onAlarmRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onAlarmRequest();
      _offerCrashReport();
    });
  }

  /// A tapped alarm opens the full-screen alarm page; a tapped reminder opens its item.
  void _onAlarmRequest() {
    final r = widget.controller.alarmRequest.value;
    if (r == null || !mounted) return;
    widget.controller.alarmRequest.value = null;
    final c = widget.controller;
    final s = c.schedule, contacts = c.contacts;
    if (s == null || contacts == null) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => r.alarm
          ? AlarmPage(controller: c, kind: r.kind, id: r.id)
          : (r.kind == 'task'
              ? TaskFormPage(schedule: s, contacts: contacts, id: r.id)
              : MeetingFormPage(schedule: s, contacts: contacts, id: r.id)),
    ));
  }

  /// After an unexpected close, offer to send the saved error report.
  Future<void> _offerCrashReport() async {
    final log = CrashLog.instance;
    if (log == null || !mounted) return;
    final report = await log.pending();
    if (report == null || !mounted) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final code = 'E-${(report.split('\n').skip(4).take(1).join().hashCode.abs() % 9000) + 1000}';
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        Widget line(String k, String v) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(k, style: TextStyle(fontSize: 12, color: ctx.palette.text2)),
                Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ]),
            );
        return AlertDialog(
          title: Text(l.crashTitle),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.crashBody),
              const SizedBox(height: 12),
              line(l.crashCode, code),
              line(l.crashVersion, '$appVersion+$appBuild'),
              line(l.crashAndroid, Platform.operatingSystemVersion),
              Text(l.crashNever, style: TextStyle(fontSize: 12.5, color: ctx.palette.text2)),
            ]),
          ),
          actionsOverflowAlignment: OverflowBarAlignment.end,
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l.crashSkip)),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: report));
                messenger.showSnackBar(SnackBar(content: Text(l.crashCopied)));
              },
              child: Text(l.crashCopy),
            ),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l.crashSend)),
          ],
        );
      },
    );
    await log.clear();
    if (send == true) await Share.share(report, subject: 'YONCA error report');
  }

  @override
  void dispose() {
    widget.controller.alarmRequest.removeListener(_onAlarmRequest);
    _widgetClicks?.cancel();
    widget.controller.schedule?.revision.removeListener(_syncWidget);
    super.dispose();
  }

  void _syncWidget() {
    final s = widget.controller.schedule;
    if (s != null && mounted) syncHomeWidget(s, AppLocalizations.of(context));
  }

  Future<void> _setupWidget() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      widget.controller.schedule?.revision.addListener(_syncWidget);
      void open(Uri? u) {
        if (u != null && u.scheme == 'yonca' && u.host != 'open') _handleAction(u.host);
      }
      _widgetClicks = HomeWidget.widgetClicked.listen(open);
      open(await HomeWidget.initiallyLaunchedFromHomeWidget());
    } catch (_) {
      // No home widget on this platform (tests, desktop).
    }
  }

  /// Long-press shortcuts on the app icon: New contact, New task, Search.
  Future<void> _setupShortcuts() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    final l = AppLocalizations.of(context);
    try {
      const qa = QuickActions();
      await qa.initialize(_handleAction);
      await qa.setShortcutItems([
        ShortcutItem(type: 'new_contact', localizedTitle: l.newContact, icon: 'ic_launcher'),
        ShortcutItem(type: 'new_task', localizedTitle: l.shortcutNewTask, icon: 'ic_launcher'),
        ShortcutItem(type: 'search', localizedTitle: l.shortcutSearch, icon: 'ic_launcher'),
      ]);
    } catch (_) {
      // No shortcuts on this platform (tests, desktop).
    }
  }

  /// "New contact": type it, import from the phone book, or scan a YONCA QR code.
  Future<String?> _chooseHowToAdd() {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    Widget option(BuildContext ctx, IconData icon, String title, String sub, String key) => Material(
          type: MaterialType.transparency,
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: p.onPrimaryContainer),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(sub),
            onTap: () => Navigator.of(ctx).pop(key),
          ),
        );
    return showGlassSheet<String>(
      context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(l.newContact, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
        option(ctx, Icons.edit_outlined, l.newContactManual, l.newContactManualBody, 'manual'),
        option(ctx, Icons.download_outlined, l.importTitle, l.newContactImportBody, 'import'),
        option(ctx, Icons.qr_code_scanner, l.scanQr, l.newContactScanBody, 'scan'),
      ]),
    );
  }

  Future<void> _add() async {
    final repo = widget.controller.contacts;
    if (repo == null) return;
    final schedule = widget.controller.schedule;
    if (_index == 3 && widget.controller.deals != null) {
      await _dealsKey.currentState?.newDeal();
      return;
    }
    if (_index == 2 && schedule != null) {
      await showAddSheet(context, schedule: schedule, contacts: repo);
      return;
    }
    final choice = await _chooseHowToAdd();
    if (choice == null || !mounted) return;
    if (choice == 'import') {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ImportPage(repo: repo)));
      return;
    }
    if (choice == 'scan') {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ScanPage(repo: repo)));
      return;
    }
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final result = await showQuickAdd(context, repo);
    if (result == null || !mounted) return;
    if (result.draft != null) {
      final id = await Navigator.of(context).push<int>(
        MaterialPageRoute(builder: (_) => ContactFormPage(repo: repo, draft: result.draft)),
      );
      if (id != null && mounted) messenger.showSnackBar(SnackBar(content: Text(l.contactSaved)));
    } else if (result.existing) {
      setState(() => _index = 1);
      _contactsKey.currentState?.openContact(result.id!);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(l.contactSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final destinations = [
      BentoDestination(Icons.home_outlined, Icons.home, l.navHome),
      BentoDestination(Icons.people_outline, Icons.people, l.navContacts),
      BentoDestination(Icons.calendar_month_outlined, Icons.calendar_month, l.navCalendar),
      BentoDestination(Icons.paid_outlined, Icons.paid, l.navDeals),
      BentoDestination(Icons.more_horiz, Icons.more_horiz, l.navMore),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: GlassBackdrop(
        child: SafeArea(
          bottom: false,
          top: _index == 4,
          child: IndexedStack(
            index: _index,
            children: [
              for (var i = 0; i < 5; i++)
                i == 4
                    ? _MoreTab(controller: widget.controller)
                    : i == 1
                        ? ContactsTab(
                            key: _contactsKey,
                            repo: widget.controller.contacts,
                            activities: widget.controller.activities,
                            schedule: widget.controller.schedule,
                            deals: widget.controller.deals,
                            fields: widget.controller.fields,
                          )
                        : i == 2
                            ? CalendarTab(
                                schedule: widget.controller.schedule,
                                contacts: widget.controller.contacts,
                                onOpenContact: (id) {
                                  setState(() => _index = 1);
                                  _contactsKey.currentState?.openContact(id);
                                },
                              )
                            : i == 3
                                ? DealsTab(key: _dealsKey, deals: widget.controller.deals, contacts: widget.controller.contacts)
                                : HomeTab(
                                    key: _homeKey,
                                    controller: widget.controller,
                                    onNewContact: _add,
                                    onGoTab: (n) => setState(() => _index = n),
                                    onOpenContact: (id) {
                                      setState(() => _index = 1);
                                      _contactsKey.currentState?.openContact(id);
                                    },
                                  ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: Text(_index == 1 ? l.newContact : (_index == 3 ? l.newDeal : l.add)),
      ),
      bottomNavigationBar: BentoNavBar(
        destinations: destinations,
        selectedIndex: _index,
        onSelected: (i) {
          setState(() => _index = i);
          if (i == 0) _homeKey.currentState?.reload();
        },
      ),
    );
  }
}

/// More tab (design M1): profile card, then Work, Organize, Tools and Data groups, then Settings.
class _MoreTab extends StatefulWidget {
  const _MoreTab({required this.controller});
  final AppController controller;

  @override
  State<_MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<_MoreTab> {
  String _name = '';
  int _dupes = 0;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final n = (await controller.database?.getSetting('profile.name') ?? '').trim();
    final d = await controller.contacts?.duplicateGroups() ?? const [];
    if (!mounted) return;
    setState(() {
      _name = n;
      _dupes = d.length;
    });
  }

  Future<void> _shareProfile() async {
    final db = controller.database;
    if (db == null) return;
    final title = AppLocalizations.of(context).profileTitle;
    final v = {for (final k in const ['profile.name', 'profile.company', 'profile.phone', 'profile.email']) k: await db.getSetting(k) ?? ''};
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QrShowPage(title: title, data: profileVCard(v))));
  }

  Future<void> _push(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final contacts = controller.contacts;
    final activities = controller.activities;
    final db = controller.database;
    Widget group(String title, List<Widget> children) => children.isEmpty
        ? const SizedBox.shrink()
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionLabel(title),
            SettingsGroup(children: children),
          ]);
    Widget row(IconData icon, String label, VoidCallback onTap, {Widget? trailing}) =>
        SettingsRow(icon: icon, title: label, chevron: true, trailing: trailing, onTap: onTap);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
          child: Text(l.navMore, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: p.text)),
        ),
        if (db != null)
          GlassCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _push(ProfilePage(db: db)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.primary, borderRadius: BorderRadius.circular(18)),
                      child: Text(_name.isEmpty ? '' : _name.characters.first.toUpperCase(),
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: p.onPrimary)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_name.isEmpty ? l.profileTitle : _name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        Text(l.profileTitle, style: TextStyle(fontSize: 13, color: p.text2)),
                      ]),
                    ),
                    SizedBox(
                      width: 108,
                      child: PillButton(label: l.shareLabel, icon: Icons.ios_share, outlined: true, height: 40, onPressed: _shareProfile),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        group(l.moreWork, [
          if (activities != null && contacts != null)
            row(Icons.history, l.timelineTitle, () => _push(TimelinePage(activities: activities, contacts: contacts, schedule: controller.schedule))),
          if (controller.stats != null) row(Icons.insights_outlined, l.statsTitle, () => _push(StatsPage(controller: controller))),
          if (contacts != null && activities != null) row(Icons.summarize_outlined, l.reportsTitle, () => _push(ReportsPage(controller: controller))),
        ]),
        group(l.moreOrganize, [
          if (contacts != null) row(Icons.sell_outlined, l.moreTags, () => _push(TagsPage(repo: contacts))),
          if (activities != null) row(Icons.checklist, l.outcomeListTitle, () => _push(OutcomeListPage(activities: activities))),
          if (controller.fields != null) row(Icons.tune, l.customFieldsTitle, () => _push(FieldsPage(fields: controller.fields!))),
          if (controller.deals != null) row(Icons.view_kanban_outlined, l.stagesTitle, () => _push(StagesPage(deals: controller.deals!))),
        ]),
        group(l.moreTools, [
          if (contacts != null) row(Icons.qr_code_2, l.qrGeneratorTitle, () => _push(QrGeneratorPage(repo: contacts))),
          if (contacts != null) row(Icons.qr_code_scanner, l.scanQr, () => _push(ScanPage(repo: contacts))),
          if (contacts != null) row(Icons.download_outlined, l.importContacts, () => _push(ImportPage(repo: contacts))),
          if (contacts != null)
            row(
              Icons.merge_type,
              l.duplicatesTitle,
              () => _push(DuplicatesPage(repo: contacts)),
              trailing: _dupes == 0
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: p.error, borderRadius: BorderRadius.circular(10)),
                      child: Text('$_dupes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onError)),
                    ),
            ),
        ]),
        group(l.groupData, [
          if (db != null) row(Icons.backup_outlined, l.dataTitle, () => _push(DataPage(controller: controller))),
        ]),
        const SizedBox(height: 16),
        SettingsGroup(children: [row(Icons.settings_outlined, l.settingsTitle, () => _push(SettingsPage(controller: controller)))]),
      ],
    );
  }
}
