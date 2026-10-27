import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../domain/activity_models.dart';
import '../../domain/contact_models.dart';
import '../../domain/deal_models.dart';
import '../../domain/schedule_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../activities/activity_card.dart';
import '../contacts/contact_details_page.dart';
import '../contacts/contact_form_page.dart';
import '../contacts/contact_row.dart';
import '../deals/deal_detail_page.dart';
import '../deals/deal_widgets.dart';
import '../schedule/schedule_widgets.dart';

/// Global search (design S03): contacts, notes, tasks, meetings and deals in one list.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _query = TextEditingController();
  String _last = '';
  List<ContactSummary> _contacts = const [];
  List<ActivityItem> _notes = const [];
  List<ScheduleItem> _schedule = const [];
  List<DealItem> _deals = const [];
  bool _searched = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _run(String q) async {
    _last = q;
    final c = widget.controller;
    if (q.trim().isEmpty) {
      setState(() {
        _searched = false;
        _contacts = const [];
        _notes = const [];
        _schedule = const [];
        _deals = const [];
      });
      return;
    }
    final contacts = await c.contacts?.list(query: q) ?? const <ContactSummary>[];
    final lower = q.trim().toLowerCase();
    final notes = [
      for (final a in await c.activities?.list(types: {ActivityType.note}) ?? const <ActivityItem>[])
        if (a.activity.title.toLowerCase().contains(lower) || a.activity.description.toLowerCase().contains(lower)) a,
    ];
    final schedule = await c.schedule?.search(q) ?? const <ScheduleItem>[];
    final deals = await c.deals?.listDeals(query: q) ?? const <DealItem>[];
    if (!mounted || _last != q) return;
    setState(() {
      _searched = true;
      _contacts = contacts;
      _notes = notes;
      _schedule = schedule;
      _deals = deals;
    });
  }

  Widget _header(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.controller;
    final none = _contacts.isEmpty && _notes.isEmpty && _schedule.isEmpty && _deals.isEmpty;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          HeaderBand(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(children: [
              GlassIconButton(icon: Icons.arrow_back, onHeader: true, onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 12),
              Expanded(child: SearchPill(controller: _query, hint: l.searchHint, onChanged: _run, autofocus: true, border: false)),
            ]),
          ),
          Expanded(
            child: !_searched
                ? EmptyState(icon: Icons.search, title: l.searchEmpty)
                : none
                    ? EmptyState(
                        icon: Icons.search,
                        title: l.searchNoResults,
                        body: l.searchNoResultsBody(_query.text.trim()),
                        action: PillButton(
                          label: l.createContactNamed(_query.text.trim()),
                          height: 52,
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => ContactFormPage(repo: widget.controller.contacts!, draft: ContactInput(firstName: _query.text.trim())),
                          )),
                        ),
                      )
                    : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
                        if (_contacts.isNotEmpty) ...[
                          _header(l.resContacts),
                          for (final s in _contacts.take(10))
                            Material(
                              type: MaterialType.transparency,
                              child: ContactRow(
                                summary: s,
                                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                  builder: (_) => ContactDetailsPage(
                                    repo: c.contacts!,
                                    activities: c.activities,
                                    schedule: c.schedule,
                                    deals: c.deals,
                                    id: s.contact.id,
                                  ),
                                )),
                              ),
                            ),
                        ],
                        if (_notes.isNotEmpty) ...[
                          _header(l.resNotes),
                          for (final a in _notes.take(10))
                            ActivityCard(
                              item: a,
                              onTap: () => showActivitySheet(context, item: a, activities: c.activities!, contacts: c.contacts!),
                            ),
                        ],
                        if (_schedule.isNotEmpty) ...[
                          _header('${l.resTasks} · ${l.resMeetings}'),
                          for (final i in _schedule.take(15))
                            ScheduleRow(
                              item: i,
                              showDate: true,
                              onTap: () => openScheduleItem(context, item: i, schedule: c.schedule!, contacts: c.contacts!),
                            ),
                        ],
                        if (_deals.isNotEmpty) ...[
                          _header(l.resDeals),
                          for (final d in _deals.take(10))
                            DealCard(
                              item: d,
                              onTap: () => Navigator.of(context).push(MaterialPageRoute<bool>(
                                builder: (_) => DealDetailPage(deals: c.deals!, contacts: c.contacts!, id: d.deal.id),
                              )),
                            ),
                        ],
                      ]),
          ),
        ]),
      ),
    );
  }
}
