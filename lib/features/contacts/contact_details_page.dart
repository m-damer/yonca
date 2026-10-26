import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/text_normalize.dart';
import '../../data/app_database.dart';
import '../../data/contacts_repository.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../shared/state_views.dart';
import '../../theme/glass.dart';
import '../../theme/palette.dart';
import 'contact_form_page.dart';
import 'contact_widgets.dart';

/// Contact details (design S08): top bar, hero header, action row, pinned tab chips, tab content.
/// Only the Details tab has content so far; the others arrive with later milestones.
class ContactDetailsPage extends StatefulWidget {
  const ContactDetailsPage({super.key, required this.repo, required this.id});
  final ContactsRepository repo;
  final int id;

  @override
  State<ContactDetailsPage> createState() => _ContactDetailsPageState();
}

class _ContactDetailsPageState extends State<ContactDetailsPage> with SingleTickerProviderStateMixin {
  late Future<ContactSummary?> _future = widget.repo.get(widget.id);
  late final TabController _tabs = TabController(length: 5, vsync: this, initialIndex: 0);
  final _scroll = ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() => setState(() {}));
    _scroll.addListener(() {
      final c = _scroll.hasClients && _scroll.offset > 150;
      if (c != _collapsed) setState(() => _collapsed = c);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scroll.dispose();
    super.dispose();
  }

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

  Uri _tel(ContactPhone p) => Uri(scheme: 'tel', path: '${p.countryCode}${p.number}'.replaceAll(' ', ''));
  Uri _wa(ContactPhone p) => Uri.parse('https://wa.me/${normalizePhone(p.countryCode, p.number)}');

  /// What tapping an email, website or address opens. An address with a map link opens that link.
  Uri entryUri(ContactEntry e) {
    String web(String v) => v.contains('://') ? v : 'https://$v';
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
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        for (final e in list)
          _InfoRow(
            icon: icon,
            title: e.value,
            subtitle: phoneLabelText(l, e.label),
            ltrTitle: e.kind != 'address',
            onTap: () => Navigator.of(ctx).pop(e),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(l.callTitle(s.displayName), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        ),
        for (final ph in s.phones)
          _InfoRow(
            icon: Icons.phone_outlined,
            title: '${ph.countryCode} ${ph.number}',
            subtitle: phoneLabelText(l, ph.label),
            ltrTitle: true,
            onTap: () => Navigator.of(ctx).pop(ph),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.comingLater))),
        icon: const Icon(Icons.add),
        label: Text(l.add),
      ),
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

  Widget _topBar(BuildContext context, AppLocalizations l, ContactSummary s) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(children: [
        GlassIconButton(
          icon: rtl ? Icons.chevron_right : Icons.chevron_left,
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
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.25)),
              ),
            ]),
          ),
        ),
        if (_collapsed && s.phones.isNotEmpty) ...[
          GlassIconButton(icon: Icons.call_outlined, onTap: () => _call(s)),
          const SizedBox(width: 8),
        ],
        PopupMenuButton<String>(
          color: context.palette.sheet,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          onSelected: (v) => v == 'edit' ? _edit() : _delete(),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(l.edit)),
            PopupMenuItem(value: 'delete', child: Text(l.delete)),
          ],
          child: const IgnorePointer(child: GlassIconButton(icon: Icons.more_vert, onTap: null)),
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
            borderRadius: BorderRadius.circular(26),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(children: [
                Icon(icon, color: p.primary, size: 24),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l, ContactSummary s) {
    final p = context.palette;
    final c = s.contact;
    final rating = ratingFromName(c.rating);
    final waPhone = s.phones.where((x) => x.isWhatsApp).firstOrNull;
    final subtitle = s.isIncomplete
        ? l.noNameYet
        : [c.jobTitle, c.company].where((t) => t.isNotEmpty && t != s.displayName).join(' · ');
    final tabNames = [l.tabTimeline, l.tabSchedule, l.tabDeals, l.tabFiles, l.detailsTitle];
    final needsCompleting = s.isIncomplete || c.temporaryNote.trim().isNotEmpty;
    return Column(children: [
      _topBar(context, l, s),
      Expanded(
        child: NestedScrollView(
          controller: _scroll,
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(children: [
                  ContactAvatar(summary: s, size: 84),
                  const SizedBox(height: 14),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: s.displayName),
                      if (c.nickname.isNotEmpty)
                        TextSpan(text: ' · ${c.nickname}', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w400, color: p.text2)),
                    ]),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -.3),
                  ),
                  if (subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: p.text2)),
                    ),
                  if (s.roles.isNotEmpty || rating != Rating.none)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
                        for (final r in s.roles) TagPill(roleLabel(l, r), large: true),
                        if (rating != Rating.none) TagPill(ratingLabel(l, rating), icon: ratingIcon(rating), large: true),
                      ]),
                    ),
                  const SizedBox(height: 16),
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
                  if (needsCompleting) ...[
                    const SizedBox(height: 14),
                    GlassCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Icon(Icons.info_outline, color: p.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(l.completeContact, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                        ]),
                        const SizedBox(height: 6),
                        Text(c.temporaryNote.trim().isNotEmpty ? c.temporaryNote : l.completeContactBody,
                            style: TextStyle(color: p.text2, fontSize: 14)),
                        const SizedBox(height: 12),
                        PillButton(label: l.complete, height: 48, onPressed: _edit),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 14),
                ]),
              ),
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
            for (var i = 0; i < 4; i++)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(i == 0 ? l.noActivityYet : l.placeholderSoon,
                      textAlign: TextAlign.center, style: TextStyle(color: p.text2)),
                ),
              ),
            _DetailsTab(summary: s, onCall: () => _call(s), onOpen: _open, wa: _wa, tel: _tel, entryUri: entryUri),
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
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: color,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        children: [
          for (var i = 0; i < names.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: PillChip(label: names[i], selected: i == selected, onTap: () => onSelect(i)),
            ),
        ],
      ),
    );
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
            decoration: BoxDecoration(color: p.primaryContainer, borderRadius: BorderRadius.circular(14)),
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
  const _DetailsTab({required this.summary, required this.onCall, required this.onOpen, required this.wa, required this.tel, required this.entryUri});
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
          if (i > 0) Divider(height: 1, color: p.glassBorder),
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
      ],
    );
  }
}
