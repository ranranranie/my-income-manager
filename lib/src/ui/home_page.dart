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
            final compact = constraints.maxHeight < 650;
            final content = _HomeContent(
              year: year,
              currentMonth: now.month,
              records: records,
              presentTypes: presentTypes,
              monthlyByType: monthlyByType,
              monthlyTotals: monthlyTotals,
              maxMonthly: maxMonthly,
              compact: compact,
              onOpenHistory: onOpenHistory,
            );

            // Normal Android portrait screens use the available height without
            // scrolling. Small screens and large text scales can scroll safely.
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18, compact ? 10 : 16, 18, 10),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
                child: content,
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
    final gap = compact ? 8.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          year.toString() + '년 나의 수입',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: compact ? 2 : 4),
        Text(
          presentTypes.isEmpty
              ? '올해 기록된 수입이 아직 없어요.'
              : '올해 ' +
                  presentTypes.length.toString() +
                  '가지 유형의 수입이 있었어요.',
        ),
        if (presentTypes.isNotEmpty) ...[
          SizedBox(height: compact ? 6 : 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
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
        SizedBox(height: gap),
        Text(
          year.toString() + '년 수입 흐름',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 3),
        Text(
          '막대 하나가 한 달의 수입이며, 색은 수입 유형을 나타냅니다.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
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
            spacing: 10,
            runSpacing: 3,
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
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: Text(
                '최근 수입',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: onOpenHistory,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(48, 32),
              ),
              child: const Text('더보기'),
            ),
          ],
        ),
        if (records.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 12 : 18),
            child: const Center(
              child: Text('중앙 + 버튼으로 첫 수입을 기록할 수 있어요.'),
            ),
          )
        else
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
        horizontal: compact ? 8 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.label,
        style: Theme.of(context).textTheme.labelMedium,
      ),
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
    final chartHeight = compact ? 122.0 : 148.0;
    return Container(
      height: chartHeight,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
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
                        heightFactor: fraction.clamp(0.08, 1.0),
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
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          month.toString(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isFuture
                    ? Theme.of(context).colorScheme.outline
                    : null,
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
      height: 18,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45),
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 3 : 5),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(date, style: Theme.of(context).textTheme.labelSmall),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (record.source ?? record.type.label) + ' · ' + record.type.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (record.account != null)
                  Text(
                    record.account!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('₩' + record.amount.toString()),
        ],
      ),
    );
  }
}
