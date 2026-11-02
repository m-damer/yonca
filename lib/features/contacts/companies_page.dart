import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/text_normalize.dart';
import '../../data/contacts_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/ds.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import 'contact_details_page.dart';
import 'contact_row.dart';

/// All companies of the contacts, with how many contacts each has (More, Organize).
class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key, required this.controller});
  final AppController controller;

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  List<CompanyInfo>? _companies;
  String _query = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = widget.controller.contacts;
    if (repo == null) return;
    final list = await repo.companies();
    if (mounted) setState(() => _companies = list);
  }

  Future<void> _open(CompanyInfo c) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CompanyPage(controller: widget.controller, companyKey: c.key)));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final list = _companies;
    final q = normalizeText(_query);
    final shown = list == null ? const <CompanyInfo>[] : [for (final c in list) if (q.isEmpty || normalizeText(c.name).contains(q)) c];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(title: l.companiesTitle),
          Expanded(
            child: list == null
                ? const LoadingView()
                : list.isEmpty
                    ? EmptyState(icon: Icons.business_outlined, title: l.companiesTitle, body: l.companiesEmpty)
                    : Column(children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.sm),
                          child: GlassField(controller: _search, label: l.companiesSearch, onChanged: (v) => setState(() => _query = v)),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.fabClear),
                            children: [
                              GlassCard(
                                padding: EdgeInsets.zero,
                                child: Column(children: [
                                  for (var i = 0; i < shown.length; i++) ...[
                                    if (i > 0) Divider(height: 1, thickness: 1, indent: AppSpace.lg, endIndent: AppSpace.lg, color: p.separator),
                                    InkWell(
                                      onTap: () => _open(shown[i]),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.lg),
                                        child: Row(children: [
                                          Container(
                                            width: AppControl.md,
                                            height: AppControl.md,
                                            decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
                                            child: Icon(Icons.business_outlined, size: AppIcon.md, color: p.onPrimaryContainer),
                                          ),
                                          const SizedBox(width: AppSpace.md),
                                          Expanded(
                                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Text(shown[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: AppFont.body, fontWeight: FontWeight.w500, height: AppLine.normal)),
                                              Text(l.companyContactsCount(shown[i].contacts.length), style: TextStyle(fontSize: AppFont.meta, height: AppLine.normal, color: p.text2)),
                                            ]),
                                          ),
                                          Icon(Icons.chevron_right, color: p.text2),
                                        ]),
                                      ),
                                    ),
                                  ],
                                ]),
                              ),
                            ],
                          ),
                        ),
                      ]),
          ),
        ]),
      ),
    );
  }
}

/// The contacts of one company.
class CompanyPage extends StatefulWidget {
  const CompanyPage({super.key, required this.controller, required this.companyKey});
  final AppController controller;
  final String companyKey;

  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {
  CompanyInfo? _company;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = widget.controller.contacts;
    if (repo == null) return;
    final all = await repo.companies();
    final match = all.where((c) => c.key == widget.companyKey).firstOrNull;
    if (mounted) {
      setState(() {
        _company = match;
        _loaded = true;
      });
    }
  }

  Future<void> _open(int id) async {
    final c = widget.controller;
    final repo = c.contacts;
    if (repo == null) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ContactDetailsPage(repo: repo, activities: c.activities, schedule: c.schedule, deals: c.deals, fields: c.fields, id: id),
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final company = _company;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(title: company?.name ?? ''),
          Expanded(
            child: !_loaded
                ? const LoadingView()
                : company == null
                    ? const SizedBox.shrink()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.fabClear),
                        children: [
                          GlassCard(
                            padding: EdgeInsets.zero,
                            child: Column(children: [
                              for (final s in company.contacts) ContactRow(summary: s, onTap: () => _open(s.contact.id)),
                            ]),
                          ),
                        ],
                      ),
          ),
        ]),
      ),
    );
  }
}
