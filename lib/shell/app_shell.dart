import '../features/schedule/event_form_page.dart';
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';

import '../shared/glass_widgets.dart';
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
import '../features/activities/log_activity_page.dart';
import '../features/importing/import_page.dart';
import '../features/importing/scan_page.dart';
import '../features/reports/reports_page.dart';
import '../features/stats/stats_page.dart';
import '../features/schedule/calendar_tab.dart';
import '../features/search/search_page.dart';
import '../features/schedule/schedule_widgets.dart';
import '../l10n/app_localizations.dart';
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
  final _calKey = GlobalKey<CalendarTabState>();

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
          : (r.kind == 'event'
              ? EventFormPage(schedule: s, contacts: contacts, id: r.id)
              : (r.kind == 'task'
                  ? TaskFormPage(schedule: s, contacts: contacts, id: r.id)
                  : MeetingFormPage(schedule: s, contacts: contacts, id: r.id))),
    ));
  }

  /// After an unexpected close, offer to send the saved error report.
  Future<void> _offerCrashReport() async {
    final log = CrashLog.instance;
    if (log == null || !mounted) return;
    final report = await log.pending();
    if (report == null || !mounted) return;
    // Forget the file first, so a problem while showing this dialog cannot make it come back at every start.
    await log.clear();
    // Wait until the first screen is settled before putting a dialog on top of it.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
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
            DialogCancel(l.crashSkip, onPressed: () => Navigator.of(ctx).pop(false)),
            DialogCancel(l.crashCopy, onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report));
              messenger.showSnackBar(SnackBar(content: Text(l.crashCopied)));
            }),
            DialogConfirm(l.crashSend, onPressed: () => Navigator.of(ctx).pop(true)),
          ],
        );
      },
    );
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

  /// The Add button: what it does depends on the tab (design H5, C2, K3).
  Future<void> _add() async {
    final repo = widget.controller.contacts;
    if (repo == null) return;
    final schedule = widget.controller.schedule;
    if (_index == 3 && widget.controller.deals != null) {
      await _dealsKey.currentState?.newDeal();
      return;
    }
    if (_index == 2 && schedule != null) {
      await showAddSheet(context, schedule: schedule, contacts: repo, day: _calKey.currentState?.selectedDay ?? DateTime.now());
      return;
    }
    if (_index != 1 && schedule != null) {
      final c = widget.controller;
      await showAddSheet(
        context,
        schedule: schedule,
        contacts: repo,
        onNewContact: _newContact,
        onLogActivity: c.activities == null
            ? null
            : () => Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => LogActivityPage(activities: c.activities!, contacts: repo, schedule: schedule))),
        onNewDeal: c.deals == null
            ? null
            : () {
                setState(() => _index = 3);
                WidgetsBinding.instance.addPostFrameCallback((_) => _dealsKey.currentState?.newDeal());
              },
      );
      return;
    }
    await _newContact();
  }

  Future<void> _newContact() async {
    final repo = widget.controller.contacts;
    if (repo == null) return;
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
      BentoDestination(Icons.more_vert, Icons.more_vert, l.navMore),
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
                            navBar: (ctx) => BentoNavBar(
                              destinations: destinations,
                              selectedIndex: 1,
                              onSelected: (n) {
                                Navigator.of(ctx).popUntil((r) => r.isFirst);
                                setState(() => _index = n);
                                if (n == 0) _homeKey.currentState?.reload();
                              },
                            ),
                          )
                        : i == 2
                            ? CalendarTab(
                                key: _calKey,
                                schedule: widget.controller.schedule,
                                contacts: widget.controller.contacts,
                                onOpenContact: (id) {
                                  setState(() => _index = 1);
                                  _contactsKey.currentState?.openContact(id);
                                },
                              )
                            : i == 3
                                ? DealsTab(key: _dealsKey, deals: widget.controller.deals, contacts: widget.controller.contacts, fields: widget.controller.fields)
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
      floatingActionButton: _index == 4
          ? null
          : FloatingActionButton.extended(
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
    final v = {for (final k in profileKeys) k: await db.getSetting(k) ?? ''};
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
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
              child: Text(title.toUpperCase(), style: TextStyle(fontSize: 15, height: 21 / 15, fontWeight: FontWeight.w600, color: p.text2)),
            ),
            SettingsGroup(children: children),
          ]);
    Widget row(IconData icon, String label, VoidCallback onTap, {Widget? trailing}) =>
        SettingsRow(icon: icon, title: label, chevron: true, trailing: trailing, onTap: onTap);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          child: Text(l.navMore, style: TextStyle(fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w600, color: p.text)),
        ),
        if (db != null)
          GlassCard(
            padding: EdgeInsets.zero,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _push(ProfilePage(db: db)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 17.3, 16, 17.3),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.separator, borderRadius: BorderRadius.circular(8)),
                      child: Text(_name.isEmpty ? '' : _name.characters.first.toUpperCase(),
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: p.text)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_name.isEmpty ? l.profileTitle : _name, style: const TextStyle(fontSize: 19, height: 24 / 19, fontWeight: FontWeight.w600)),
                        Text(l.profileTitle, style: TextStyle(fontSize: 13.5, height: 18.9 / 13.5, color: p.text2)),
                      ]),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _shareProfile,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFC7C7CC))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.ios_share, size: 22, color: p.text),
                          const SizedBox(width: 6),
                          Text(l.shareLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.text)),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        group(l.moreWork, [
          if (activities != null && contacts != null)
            row(Icons.schedule, l.timelineTitle, () => _push(TimelinePage(activities: activities, contacts: contacts, schedule: controller.schedule))),
          if (controller.stats != null) row(Icons.track_changes, l.statsTitle, () => _push(StatsPage(controller: controller))),
          if (contacts != null && activities != null) row(Icons.insert_drive_file_outlined, l.reportsTitle, () => _push(ReportsPage(controller: controller))),
        ]),
        group(l.moreOrganize, [
          if (contacts != null) row(Icons.place_outlined, l.moreTags, () => _push(TagsPage(repo: contacts))),
          if (activities != null) row(Icons.check, l.outcomeListTitle, () => _push(OutcomeListPage(activities: activities))),
          if (controller.fields != null) row(Icons.edit_outlined, l.customFieldsTitle, () => _push(FieldsPage(fields: controller.fields!))),
          if (controller.deals != null) row(Icons.swap_horiz, l.stagesTitle, () => _push(StagesPage(deals: controller.deals!))),
        ]),
        group(l.moreTools, [
          if (contacts != null) row(Icons.qr_code_2, l.qrGeneratorTitle, () => _push(QrGeneratorPage(repo: contacts))),
          if (contacts != null) row(Icons.zoom_in, l.scanQr, () => _push(ScanPage(repo: contacts))),
          if (contacts != null) row(Icons.download, l.importContacts, () => _push(ImportPage(repo: contacts))),
          if (contacts != null)
            row(
              Icons.subdirectory_arrow_right,
              l.duplicatesTitle,
              () => _push(DuplicatesPage(repo: contacts)),
              trailing: _dupes == 0
                  ? null
                  : Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: p.error, shape: BoxShape.circle),
                      child: Text('$_dupes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onError)),
                    ),
            ),
        ]),
        group(l.groupData, [
          if (db != null) row(Icons.cloud_outlined, l.dataTitle, () => _push(DataPage(controller: controller))),
        ]),
        const SizedBox(height: 18),
        SettingsGroup(children: [row(Icons.settings_outlined, l.settingsTitle, () => _push(SettingsPage(controller: controller)))]),
      ],
    );
  }
}
