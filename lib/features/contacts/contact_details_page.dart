import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/text_normalize.dart';
import '../../data/app_database.dart';
import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'contact_form_page.dart';
import 'contact_widgets.dart';

/// Contact details: header, action row, pinned tabs. Only the Details tab has content so far.
class ContactDetailsPage extends StatefulWidget {
  const ContactDetailsPage({super.key, required this.repo, required this.id});
  final ContactsRepository repo;
  final int id;

  @override
  State<ContactDetailsPage> createState() => _ContactDetailsPageState();
}

class _ContactDetailsPageState extends State<ContactDetailsPage> {
  late Future<ContactSummary?> _future = widget.repo.get(widget.id);

  void _reload() => setState(() => _future = widget.repo.get(widget.id));

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => ContactFormPage(repo: widget.repo, id: widget.id)),
    );
    if (saved != null && mounted) _reload();
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
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  Future<void> _call(ContactSummary s) async {
    if (s.phones.length == 1) {
      _open(Uri(scheme: 'tel', path: '${s.phones.first.countryCode}${s.phones.first.number}'.replaceAll(' ', '')));
      return;
    }
    final l = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<ContactPhone>(
      context: context,
      backgroundColor: context.palette.sheet,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(l.chooseNumber, style: Theme.of(ctx).textTheme.titleLarge),
            ),
          ),
          for (final ph in s.phones)
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: Text('${ph.countryCode} ${ph.number}', textDirection: TextDirection.ltr),
              subtitle: Text(phoneLabelText(l, ph.label)),
              onTap: () => Navigator.of(ctx).pop(ph),
            ),
        ]),
      ),
    );
    if (picked != null) {
      _open(Uri(scheme: 'tel', path: '${picked.countryCode}${picked.number}'.replaceAll(' ', '')));
    }
  }

  List<Widget> _actions(AppLocalizations l, ContactSummary s) {
    final wa = s.phones.where((p) => p.isWhatsApp).toList();
    final c = s.contact;
    Widget btn(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(children: [
                Icon(icon, color: context.palette.primary),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 12)),
              ]),
            ),
          ),
        );
    return [
      if (wa.isNotEmpty)
        btn(Icons.chat_outlined, l.actionWhatsApp, () {
          _open(Uri.parse('https://wa.me/${normalizePhone(wa.first.countryCode, wa.first.number)}'));
        }),
      if (s.phones.isNotEmpty) btn(Icons.call_outlined, l.actionCall, () => _call(s)),
      if (c.email.isNotEmpty) btn(Icons.email_outlined, l.actionEmail, () => _open(Uri(scheme: 'mailto', path: c.email))),
      if (c.address.isNotEmpty)
        btn(Icons.map_outlined, l.actionMap, () => _open(Uri.parse('geo:0,0?q=${Uri.encodeComponent(c.address)}'))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: SafeArea(
          child: FutureBuilder<ContactSummary?>(
            future: _future,
            builder: (context, snap) {
              if (snap.hasError) return ErrorView(onRetry: _reload);
              if (!snap.hasData) return const LoadingView();
              return _body(context, l, snap.data!);
            },
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l, ContactSummary s) {
    final p = context.palette;
    final c = s.contact;
    final rating = ratingFromName(c.rating);
    final subtitle = [c.company, c.jobTitle].where((t) => t.isNotEmpty && t != s.displayName).join(' · ');
    final actions = _actions(l, s);
    final tabs = [l.tabTimeline, l.tabSchedule, l.tabDeals, l.tabFiles, l.detailsTitle];
    return DefaultTabController(
      length: tabs.length,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(children: [
                Row(children: [
                  const BackButton(),
                  const Spacer(),
                  PopupMenuButton<String>(
                    onSelected: (v) => v == 'edit' ? _edit() : _delete(),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'edit', child: Text(l.edit)),
                      PopupMenuItem(value: 'delete', child: Text(l.delete)),
                    ],
                  ),
                ]),
                ContactAvatar(summary: s, size: 88, showRating: true),
                const SizedBox(height: 12),
                Text(s.displayName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                if (c.nickname.isNotEmpty) Text(c.nickname, style: TextStyle(color: p.text2)),
                if (subtitle.isNotEmpty) Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: p.text2)),
                const SizedBox(height: 8),
                Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 4, children: [
                  if (rating != Rating.none)
                    Chip(
                      avatar: Icon(ratingIcon(rating), size: 16, color: ratingColor(rating)),
                      label: Text(ratingLabel(l, rating)),
                    ),
                  for (final r in s.roles) Chip(label: Text(roleLabel(l, r))),
                ]),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GlassCard(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: actions)),
                ],
                if (c.requirements.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  GlassCard(child: _Collapsible(text: c.requirements, more: l.showMore, less: l.showLess)),
                ],
                if (c.temporaryNote.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _edit,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(18)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.completeBanner,
                            style: TextStyle(color: p.onPrimaryContainer, fontWeight: FontWeight.w700)),
                        Text(c.temporaryNote, style: TextStyle(color: p.onPrimaryContainer)),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabsHeader(
              TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final t in tabs) Tab(text: t)]),
              p.bg,
            ),
          ),
        ],
        body: TabBarView(children: [
          for (var i = 0; i < 4; i++) EmptyState(icon: Icons.hourglass_empty, title: tabs[i], body: l.placeholderSoon),
          _DetailsTab(summary: s),
        ]),
      ),
    );
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  _TabsHeader(this.bar, this.color);
  final TabBar bar;
  final Color color;
  @override
  double get minExtent => bar.preferredSize.height;
  @override
  double get maxExtent => bar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: color, child: bar);
  @override
  bool shouldRebuild(covariant _TabsHeader old) => old.bar != bar || old.color != color;
}

class _Collapsible extends StatefulWidget {
  const _Collapsible({required this.text, required this.more, required this.less});
  final String text;
  final String more;
  final String less;
  @override
  State<_Collapsible> createState() => _CollapsibleState();
}

class _CollapsibleState extends State<_Collapsible> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final long = widget.text.length > 120 || '\n'.allMatches(widget.text).length >= 2;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.text, maxLines: _open ? null : 3, overflow: _open ? null : TextOverflow.ellipsis),
      if (long)
        TextButton(onPressed: () => setState(() => _open = !_open), child: Text(_open ? widget.less : widget.more)),
    ]);
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.summary});
  final ContactSummary summary;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = context.palette;
    final s = summary;
    final c = s.contact;
    final rows = <(IconData, String)>[
      for (final ph in s.phones)
        (Icons.phone_outlined, '${ph.countryCode} ${ph.number} · ${phoneLabelText(l, ph.label)}'),
      if (c.email.isNotEmpty) (Icons.email_outlined, c.email),
      if (c.address.isNotEmpty) (Icons.place_outlined, c.address),
      if (c.website.isNotEmpty) (Icons.language, c.website),
      if (s.tags.isNotEmpty) (Icons.sell_outlined, s.tags.map((t) => '#${t.name}').join('  ')),
      if (c.requirements.isNotEmpty) (Icons.checklist_outlined, c.requirements),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        GlassCard(
          child: Column(children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Icon(r.$1, color: p.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(r.$2)),
                ]),
              ),
          ]),
        ),
      ],
    );
  }
}
