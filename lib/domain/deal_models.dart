import 'package:flutter/foundation.dart' show ValueNotifier;
import '../data/app_database.dart';

enum StageKind { open, won, lost }

StageKind stageKindFromName(String s) => StageKind.values.firstWhere((k) => k.name == s, orElse: () => StageKind.open);

/// Built-in open stages, in order. Won and Lost are added after them.
const defaultStageKeys = ['lead', 'contacted', 'quote', 'talks'];

const maxOpenStages = 8;

/// Number of fixed stage tints (design `color.stageTints`).
const stageTintCount = 10;

/// Currencies a deal can use. Amounts are never converted.
const dealCurrencies = ['USD', 'SYP', 'EUR'];

/// A currency the person added themselves (Settings › Deals).
class CurrencyDef {
  const CurrencyDef({required this.code, required this.symbol, required this.name, this.decimals = 2, this.symbolAfter = true});
  final String code;
  final String symbol;
  final String name;
  final int decimals;
  final bool symbolAfter;

  Map<String, Object> toJson() => {'code': code, 'symbol': symbol, 'name': name, 'decimals': decimals, 'after': symbolAfter};
  static CurrencyDef? fromJson(Object? j) {
    if (j is! Map) return null;
    final code = j['code'];
    if (code is! String || code.isEmpty) return null;
    return CurrencyDef(
      code: code,
      symbol: j['symbol'] is String ? j['symbol'] as String : code,
      name: j['name'] is String ? j['name'] as String : code,
      decimals: j['decimals'] is int ? j['decimals'] as int : 2,
      symbolAfter: j['after'] is bool ? j['after'] as bool : true,
    );
  }
}

/// Custom currencies, loaded at start and changed in settings.
final customCurrencies = ValueNotifier<List<CurrencyDef>>(const []);

/// Built-in codes followed by the custom ones.
List<String> allCurrencyCodes() => [...dealCurrencies, for (final c in customCurrencies.value) c.code];

/// The main currency chosen in onboarding; new deals start with it.
String defaultDealCurrency = 'USD';

/// Reasons offered when a deal is lost.
const lostReasonKeys = ['price', 'competitor', 'noBudget', 'noResponse', 'other'];

class DealInput {
  const DealInput({
    required this.title,
    required this.contactId,
    this.amount,
    this.currency = 'USD',
    required this.stageId,
    this.expectedClose,
    this.description = '',
  });
  final String title;
  final int? contactId;
  final double? amount;
  final String currency;
  final int stageId;
  final DateTime? expectedClose;
  final String description;

  String? problem() {
    if (title.trim().isEmpty) return 'title';
    if (contactId == null) return 'contact';
    if (amount != null && amount! < 0) return 'amount';
    return null;
  }
}

class DealValidationException implements Exception {
  const DealValidationException(this.problem);
  final String problem;
  @override
  String toString() => problem;
}

/// A deal with what the cards need: its stage and the contact's name.
class DealItem {
  const DealItem({required this.deal, required this.stage, required this.contactName, required this.now});
  final Deal deal;
  final DealStage stage;
  final String contactName;
  final DateTime now;

  StageKind get kind => stageKindFromName(stage.kind);
  bool get isOpen => kind == StageKind.open;

  int get daysInStage => now.difference(deal.stageChangedAt).inDays;

  bool get pastClose {
    final c = deal.expectedClose;
    if (c == null || !isOpen) return false;
    return DateTime(c.year, c.month, c.day).isBefore(DateTime(now.year, now.month, now.day));
  }
}

/// A stage with how many deals it holds and their totals per currency.
class StageSummary {
  const StageSummary({required this.stage, required this.count, required this.totals});
  final DealStage stage;
  final int count;
  final Map<String, double> totals;
}

class StageMove {
  const StageMove({required this.fromStage, required this.toStage, required this.at});
  final DealStage? fromStage;
  final DealStage toStage;
  final DateTime at;
}
