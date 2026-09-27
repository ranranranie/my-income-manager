import 'package:flutter/material.dart';

import '../data/income_database.dart';
import '../models/income_models.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.revision,
    required this.onOpenHistory,
  });

  final int revision;
  final VoidCallback onOpenHistory;

  static const _typeColors = <IncomeType, Color>{
    IncomeType.salary: Color(0xff806d4f),
    IncomeType.bonus: Color(0xffb58a57),
    IncomeType.dividend: Color(0xff68856d),
    IncomeType.interest: Color(0xff6f8297),
    IncomeType.sideJob: Color(0xff987487),
    IncomeType.appTech: Color(0xff9a8c5c),
    IncomeType.other: Color(0xff8b8177),
  };

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final year = now.year;

    return FutureBuilder<List<IncomeRecord>>(
      key: ValueKey(revision),
      future: IncomeDatabase.instance.forYear(year),
      builder: (context, snapshot) {
        final records = snapshot.data ?? const <IncomeRecord>[];
        final presentTypes = IncomeType.values
            .where((type) => records.any((record) => record.type == type))
            .toList();

        // Keep the existing annual aggregation: each month contains the
        // recorded amount for each type and its height is based on real totals.
        final monthlyByType = List.generate(
          12,
          (monthIndex) => <IncomeType, int>{
            for (final type in presentTypes)
              type: records
                  .where((record) =>
                      record.date.month == monthIndex + 1 &&
                      record.type == type)
                  .fold<int>(0, (sum, record) => sum + record.amount),
          },
        );
        final monthlyTotals = monthlyByType
            .map((values) => values.values.fold<int>(0, (a, b) => a + b))
            .toList();
        final maxMonthly = monthlyTotals.fold<int>(
          0,
          (current, value) => value > current ? value : current,
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final compact = constraints.maxHeight < 700 || textScale > 1.1;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18, compact ? 10 : 14, 18, 10),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 20).clamp(0.0, double.infinity).toDouble(),
                ),
                child: _HomeContent(
                  year: year,
                  currentMonth: now.month,
                  records: records,
                  presentTypes: presentTypes,
                  monthlyByType: monthlyByType,
                  monthlyTotals: monthlyTotals,
                  maxMonthly: maxMonthly,
                  compact: compact,
                  onOpenHistory: onOpenHistory,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.year,
    required this.currentMonth,
    required this.records,
    required this.presentTypes,
    required this.monthlyByType,
    required this.monthlyTotals,
    required this.maxMonthly,
    required this.compact,
    required this.onOpenHistory,
  });

  final int year;
  final int currentMonth;
  final List<IncomeRecord> records;
  final List<IncomeType> presentTypes;
  final List<Map<IncomeType, int>> monthlyByType;
  final List<int> monthlyTotals;
  final int maxMonthly;
  final bool compact;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final sectionGap = compact ? 11.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(year: year, compact: compact),
        SizedBox(height: sectionGap),
        _SectionTitle(title: '올해의 수입'),
        const SizedBox(height: 3),
        Text(
          presentTypes.isEmpty
              ? '올해 기록된 수입이 아직 없어요.'
              : presentTypes.length.toString() + '가지 유형의 수입이 있어요.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (presentTypes.isNotEmpty) ...[
          SizedBox(height: compact ? 6 : 8),
          Wrap(
            spacing: 6,
            runSpacing: compact ? 3 : 5,
            children: presentTypes
                .map(
                  (type) => _TypeChip(
                    type: type,
                    color: HomePage._typeColors[type]!,
                    compact: compact,
                  ),
                )
                .toList(),
          ),
        ],
        SizedBox(height: sectionGap),
        _SectionTitle(title: year.toString() + '년 수입 흐름'),
        SizedBox(height: compact ? 5 : 7),
        _IncomeFlowChart(
          currentMonth: currentMonth,
          presentTypes: presentTypes,
          monthlyByType: monthlyByType,
          monthlyTotals: monthlyTotals,
          maxMonthly: maxMonthly,
          compact: compact,
        ),
        if (presentTypes.isNotEmpty) ...[
          SizedBox(height: compact ? 5 : 7),
          Wrap(
            spacing: 9,
            runSpacing: 2,
            children: presentTypes
                .map(
                  (type) => _LegendItem(
                    label: type.label,
                    color: HomePage._typeColors[type]!,
                  ),
                )
                .toList(),
          ),
        ],
        SizedBox(height: sectionGap),
        Row(
          children: [
            const Expanded(child: _SectionTitle(title: '최근 수입')),
            TextButton(
              onPressed: onOpenHistory,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(64, 40),
              ),
              child: const Text('전체 보기'),
            ),
          ],
        ),
        if (records.isNotEmpty)
          ...records.take(3).map(
                (record) => _RecentIncomeRow(
                  record: record,
                  compact: compact,
                ),
              ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.year, required this.compact});

  final int year;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Income Manager',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: compact ? 1 : 2),
        Text(
          year.toString() + '년',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.type,
    required this.color,
    required this.compact,
  });

  final IncomeType type;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(type.label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _IncomeFlowChart extends StatelessWidget {
  const _IncomeFlowChart({
    required this.currentMonth,
    required this.presentTypes,
    required this.monthlyByType,
    required this.monthlyTotals,
    required this.maxMonthly,
    required this.compact,
  });

  final int currentMonth;
  final List<IncomeType> presentTypes;
  final List<Map<IncomeType, int>> monthlyByType;
  final List<int> monthlyTotals;
  final int maxMonthly;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final chartHeight = compact ? 116.0 : 142.0;

    return Container(
      height: chartHeight,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(12, (index) {
          final month = index + 1;
          final isFuture = month > currentMonth;
          final hasIncome = monthlyTotals[index] > 0;

          return Expanded(
            child: _MonthBar(
              month: month,
              isFuture: isFuture,
              hasIncome: hasIncome,
              values: monthlyByType[index],
              presentTypes: presentTypes,
              maxMonthly: maxMonthly,
            ),
          );
        }),
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.isFuture,
    required this.hasIncome,
    required this.values,
    required this.presentTypes,
    required this.maxMonthly,
  });

  final int month;
  final bool isFuture;
  final bool hasIncome;
  final Map<IncomeType, int> values;
  final List<IncomeType> presentTypes;
  final int maxMonthly;

  @override
  Widget build(BuildContext context) {
    final total = values.values.fold<int>(0, (a, b) => a + b);
    final fraction = maxMonthly == 0 ? 0.0 : total / maxMonthly;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: isFuture
                ? _FutureMonthMarker()
                : hasIncome
                    ? FractionallySizedBox(
                        heightFactor: fraction.clamp(0.08, 1.0).toDouble(),
                        widthFactor: 0.62,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Column(
                            children: [
                              for (final type in presentTypes)
                                if ((values[type] ?? 0) > 0)
                                  Expanded(
                                    flex: values[type]!,
                                    child: ColoredBox(
                                      color: HomePage._typeColors[type]!,
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      )
                    : Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          month.toString(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isFuture
                    ? Theme.of(context).colorScheme.outline
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _FutureMonthMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 16,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .outlineVariant
            .withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _RecentIncomeRow extends StatelessWidget {
  const _RecentIncomeRow({required this.record, required this.compact});

  final IncomeRecord record;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final date = record.date.month.toString() + '.' + record.date.day.toString();
    final source = record.source?.trim();
    final primary = source == null || source.isEmpty ? record.type.label : source;
    final secondary = record.account == null || record.account!.trim().isEmpty
        ? record.type.label
        : record.type.label + ' · ' + record.account!.trim();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 3 : 5),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            child: Text(
              date,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  primary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _formatWon(record.amount),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatWon(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return (amount < 0 ? '-' : '') + buffer.toString() + '원';
}
