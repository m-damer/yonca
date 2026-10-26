import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';

import '../app_controller.dart';
import '../data/widget_sync.dart';
import '../diagnostics/alarm_test.dart';
import '../features/activities/activity_feed.dart';
import '../features/activities/outcome_list_page.dart';
import '../features/contacts/contact_form_page.dart';
import '../features/contacts/contacts_tab.dart';
import '../features/contacts/quick_add_sheet.dart';
import '../features/deals/deals_tab.dart';
import '../features/fields/fields_page.dart';
import '../features/data/data_page.dart';
import '../features/settings/settings_page.dart';
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
  }

  @override
  void dispose() {
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

/// More tab: the tools and lists that do not have a tab, grouped, with Settings at the end.
class _MoreTab extends StatelessWidget {
  const _MoreTab({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    Widget tile(IconData icon, String label, VoidCallback onTap) => ListTile(
          leading: Icon(icon, color: p.primary),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        );
    Widget group(String title, List<Widget> children) => children.isEmpty
        ? const SizedBox.shrink()
        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionLabel(title),
            GlassCard(padding: EdgeInsets.zero, child: Material(type: MaterialType.transparency, child: Column(children: children))),
          ]);
    final contacts = controller.contacts;
    final activities = controller.activities;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l.navMore, style: Theme.of(context).textTheme.titleLarge),
        group(l.moreWork, [
          if (activities != null && contacts != null)
            tile(Icons.history, l.timelineTitle, () => push(TimelinePage(activities: activities, contacts: contacts))),
          if (activities != null) tile(Icons.checklist, l.outcomeListTitle, () => push(OutcomeListPage(activities: activities))),
          if (controller.stats != null) tile(Icons.insights_outlined, l.statsTitle, () => push(StatsPage(controller: controller))),
          if (contacts != null && activities != null) tile(Icons.summarize_outlined, l.reportsTitle, () => push(ReportsPage(controller: controller))),
        ]),
        group(l.moreOrganize, [
          if (contacts != null) tile(Icons.download_outlined, l.importTitle, () => push(ImportPage(repo: contacts))),
          if (contacts != null) tile(Icons.merge_type, l.duplicatesTitle, () => push(DuplicatesPage(repo: contacts))),
          if (contacts != null) tile(Icons.qr_code_scanner, l.scanQr, () => push(ScanPage(repo: contacts))),
          if (controller.fields != null) tile(Icons.tune, l.customFieldsTitle, () => push(FieldsPage(fields: controller.fields!))),
        ]),
        group(l.moreTools, [
          if (controller.database != null) tile(Icons.backup_outlined, l.dataTitle, () => push(DataPage(controller: controller))),
          tile(Icons.settings_outlined, l.settingsTitle, () => push(SettingsPage(controller: controller))),
          tile(Icons.alarm, 'Alarm test (temporary)', () => push(const AlarmTestPage())),
        ]),
      ],
    );
  }
}
