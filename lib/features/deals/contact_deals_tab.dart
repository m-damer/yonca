import 'package:flutter/material.dart';

import '../../data/contacts_repository.dart';
import '../../data/deals_repository.dart';
import '../../domain/deal_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/state_views.dart';
import 'deal_detail_page.dart';
import 'deal_widgets.dart';

/// The Deals tab of a contact: their deals with amount and stage.
class ContactDealsTab extends StatefulWidget {
  const ContactDealsTab({super.key, required this.deals, required this.contacts, required this.contactId});
  final DealsRepository deals;
  final ContactsRepository contacts;
  final int contactId;

  @override
  State<ContactDealsTab> createState() => _ContactDealsTabState();
}

class _ContactDealsTabState extends State<ContactDealsTab> {
  List<DealItem>? _items;

  @override
  void initState() {
    super.initState();
    widget.deals.revision.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.deals.revision.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final r = await widget.deals.listDeals(contactId: widget.contactId);
    if (mounted) setState(() => _items = r);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = _items;
    if (items == null) return const SizedBox.shrink();
    if (items.isEmpty) return EmptyState(icon: Icons.paid_outlined, title: l.noDealsYet);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 120), children: [
      for (final i in items)
        DealCard(
          item: i,
          onTap: () => Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => DealDetailPage(deals: widget.deals, contacts: widget.contacts, id: i.deal.id),
          )),
        ),
    ]);
  }
}
