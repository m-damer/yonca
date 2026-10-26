import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../diagnostics/alarm_test.dart';
import '../features/activities/activity_feed.dart';
import '../features/activities/outcome_list_page.dart';
import '../features/contacts/contact_form_page.dart';
import '../features/contacts/contacts_tab.dart';
import '../features/contacts/quick_add_sheet.dart';
import '../features/deals/deals_tab.dart';
import '../features/fields/fields_page.dart';
import '../features/home/home_tab.dart';
import '../features/importing/duplicates_page.dart';
import '../features/importing/import_page.dart';
import '../features/importing/profile_page.dart';
import '../features/importing/scan_page.dart';
import '../features/reports/reports_page.dart';
import '../features/stats/stats_page.dart';
import '../features/schedule/calendar_tab.dart';
import '../features/schedule/schedule_widgets.dart';
import '../l10n/app_localizations.dart';
import '../theme/glass.dart';
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

/// Temporary More tab: language and theme switches so both modes can be checked on a phone.
class _MoreTab extends StatelessWidget {
  const _MoreTab({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isArabic = controller.locale.languageCode == 'ar';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.navMore, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (controller.contacts != null) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ImportPage(repo: controller.contacts!))),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(l.importTitle),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DuplicatesPage(repo: controller.contacts!))),
                  icon: const Icon(Icons.merge_type),
                  label: Text(l.duplicatesTitle),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ScanPage(repo: controller.contacts!))),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(l.scanQr),
                ),
                const SizedBox(height: 8),
              ],
              if (controller.database != null) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProfilePage(db: controller.database!))),
                  icon: const Icon(Icons.account_circle_outlined),
                  label: Text(l.profileTitle),
                ),
                const SizedBox(height: 8),
              ],
              if (controller.stats != null) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StatsPage(controller: controller))),
                  icon: const Icon(Icons.insights_outlined),
                  label: Text(l.statsTitle),
                ),
                const SizedBox(height: 8),
              ],
              if (controller.contacts != null && controller.activities != null) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReportsPage(controller: controller))),
                  icon: const Icon(Icons.summarize_outlined),
                  label: Text(l.reportsTitle),
                ),
                const SizedBox(height: 8),
              ],
              if (controller.fields != null) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FieldsPage(fields: controller.fields!))),
                  icon: const Icon(Icons.tune),
                  label: Text(l.customFieldsTitle),
                ),
                const SizedBox(height: 8),
              ],
              if (controller.activities != null && controller.contacts != null) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => TimelinePage(activities: controller.activities!, contacts: controller.contacts!),
                  )),
                  icon: const Icon(Icons.history),
                  label: Text(l.timelineTitle),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => OutcomeListPage(activities: controller.activities!),
                  )),
                  icon: const Icon(Icons.checklist),
                  label: Text(l.outcomeListTitle),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: () => controller.setLocale(Locale(isArabic ? 'en' : 'ar')),
                child: Text(l.switchLanguage),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => controller.setThemeMode(
                  Theme.of(context).brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark,
                ),
                child: const Icon(Icons.brightness_6_outlined),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const AlarmTestPage())),
                child: const Text('Alarm test (temporary)'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
