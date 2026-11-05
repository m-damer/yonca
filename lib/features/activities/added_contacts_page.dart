import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../domain/contact_models.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/glass_widgets.dart';
import '../../theme/glass.dart';
import '../../theme/tokens.dart';
import '../contacts/contact_details_page.dart';
import '../contacts/contact_row.dart';

/// The contacts of an "N contacts added" line on Home or the Timeline, newest first.
class AddedContactsPage extends StatefulWidget {
  const AddedContactsPage({super.key, required this.controller, required this.ids});
  final AppController controller;
  final List<int> ids;

  @override
  State<AddedContactsPage> createState() => _AddedContactsPageState();
}

class _AddedContactsPageState extends State<AddedContactsPage> {
  List<ContactSummary>? _contacts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.controller.contacts?.byIds(widget.ids) ?? const <ContactSummary>[];
    if (mounted) setState(() => _contacts = list);
  }

  void _open(int id) {
    final c = widget.controller;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ContactDetailsPage(repo: c.contacts!, activities: c.activities, schedule: c.schedule, deals: c.deals, fields: c.fields, id: id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final list = _contacts;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackdrop(
        child: Column(children: [
          PageHeader(title: l.sysContactsAdded(widget.ids.length)),
          Expanded(
            child: list == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.x5),
                    itemCount: list.length,
                    itemBuilder: (_, i) => Material(type: MaterialType.transparency, child: ContactRow(summary: list[i], onTap: () => _open(list[i].contact.id))),
                  ),
          ),
        ]),
      ),
    );
  }
}
