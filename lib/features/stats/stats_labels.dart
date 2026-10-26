import '../../domain/stats_models.dart';
import '../../l10n/app_localizations.dart';

String metricLabel(AppLocalizations l, Metric m) => switch (m) {
      Metric.calls => l.metricCalls,
      Metric.visits => l.metricVisits,
      Metric.meetings => l.metricMeetings,
      Metric.messages => l.metricMessages,
      Metric.newContacts => l.metricNewContacts,
      Metric.dealsWon => l.metricDealsWon,
      Metric.valueWonUsd => l.metricValueUsd,
      Metric.valueWonSyp => l.metricValueSyp,
    };

String formatNumber(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
