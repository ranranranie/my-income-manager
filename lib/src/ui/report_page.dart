import 'package:flutter/material.dart';
import '../data/income_database.dart';
import '../models/income_models.dart';
import '../report/income_report.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key, required this.revision});
  final int revision;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  late int selectedYear;

  @override
  void initState() {
    super.initState();
    selectedYear = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<IncomeRecord>>(
      key: ValueKey(widget.revision),
      future: IncomeDatabase.instance.all(),
      builder: (context, snapshot) {
        final allRecords = snapshot.data ?? const <IncomeRecord>[];
        final selectedRecords = allRecords
            .where((record) => record.date.year == selectedYear)
            .toList();
        final availableYears =
            allRecords.map((record) => record.date.year).toSet().toList()
              ..sort();
        final currentYear = DateTime.now().year;
        if (!availableYears.contains(currentYear)) {
          availableYears.add(currentYear);
          availableYears.sort();
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Text(
              '리포트',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _YearPicker(
              year: selectedYear,
              canGoPrevious: availableYears.any((year) => year < selectedYear),
              canGoNext: availableYears.any((year) => year > selectedYear),
              onPrevious: () => setState(() {
                selectedYear = availableYears.lastWhere(
                  (year) => year < selectedYear,
                );
              }),
              onNext: () => setState(() {
                selectedYear = availableYears.firstWhere(
                  (year) => year > selectedYear,
                );
              }),
            ),
            const SizedBox(height: 16),
            if (selectedRecords.isEmpty)
              _EmptyReport(year: selectedYear)
            else ...[
              _AnnualSummary(records: selectedRecords),
              const SizedBox(height: 14),
              _TypeComposition(records: selectedRecords),
              const SizedBox(height: 14),
              _SourceComposition(records: selectedRecords),
              const SizedBox(height: 14),
              _FinancialIncome(records: selectedRecords),
            ],
            if (allRecords.isNotEmpty) ...[
              const SizedBox(height: 14),
              _IncomeHistory(records: allRecords),
            ],
          ],
        );
      },
    );
  }
}

class _YearPicker extends StatelessWidget {
  const _YearPicker({
    required this.year,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int year;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: canGoPrevious ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
          tooltip: '이전 기록 연도',
        ),
        SizedBox(
          width: 120,
          child: Text(
            year.toString() + '년',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          tooltip: '다음 기록 연도',
        ),
      ],
    );
  }
}

class _AnnualSummary extends StatelessWidget {
  const _AnnualSummary({required this.records});
  final List<IncomeRecord> records;

  @override
  Widget build(BuildContext context) {
    final total = IncomeReport.total(records);
    final months = IncomeReport.recordedMonths(records).length;
    final average = IncomeReport.activeMonthAverage(records);

    return _ReportSection(
      title: '연간 요약',
      child: Row(
        children: [
          Expanded(child: _Metric(label: '연간 수입', value: _won(total))),
          Expanded(child: _Metric(label: '월평균', value: _won(average))),
          Expanded(child: _Metric(label: '기록 월', value: months.toString() + '개월')),
        ],
      ),
    );
  }
}

class _TypeComposition extends StatelessWidget {
  const _TypeComposition({required this.records});
  final List<IncomeRecord> records;

  @override
  Widget build(BuildContext context) {
    final total = IncomeReport.total(records);
    final values = IncomeReport.byType(records);
    final nonSalary = IncomeReport.nonSalaryIncome(records);

    return _ReportSection(
      title: '수입 구성',
      child: Column(
        children: [
          for (final type in IncomeType.values)
            if ((values[type] ?? 0) > 0)
              _CompositionRow(
                label: type.label,
                amount: values[type]!,
                ratio: IncomeReport.ratio(values[type]!, total),
              ),
          const Divider(height: 22),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '월급 외 수입 ' +
                  _won(nonSalary) +
                  ' · 전체의 ' +
                  _percent(IncomeReport.ratio(nonSalary, total)),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceComposition extends StatelessWidget {
  const _SourceComposition({required this.records});
  final List<IncomeRecord> records;

  @override
  Widget build(BuildContext context) {
    final total = IncomeReport.total(records);
    final entries = IncomeReport.bySource(records).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const visibleCount = 5;
    final visible = entries.take(visibleCount).toList();
    final otherAmount = entries
        .skip(visibleCount)
        .fold<int>(0, (sum, entry) => sum + entry.value);

    return _ReportSection(
      title: 'Source별 구성',
      child: Column(
        children: [
          if (entries.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Source가 입력된 기록이 없습니다.'),
            )
          else ...[
            for (final entry in visible)
              _CompositionRow(
                label: entry.key,
                amount: entry.value,
                ratio: IncomeReport.ratio(entry.value, total),
              ),
            if (otherAmount > 0)
              _CompositionRow(
                label: '기타 Source',
                amount: otherAmount,
                ratio: IncomeReport.ratio(otherAmount, total),
              ),
          ],
        ],
      ),
    );
  }
}

class _FinancialIncome extends StatelessWidget {
  const _FinancialIncome({required this.records});
  final List<IncomeRecord> records;

  @override
  Widget build(BuildContext context) {
    final byType = IncomeReport.byType(records);
    final dividend = byType[IncomeType.dividend] ?? 0;
    final interest = byType[IncomeType.interest] ?? 0;
    final financial = IncomeReport.financialIncome(records);

    return _ReportSection(
      title: '금융소득',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _won(financial),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _SimpleAmountRow(label: '배당', amount: dividend),
          _SimpleAmountRow(label: '이자', amount: interest),
        ],
      ),
    );
  }
}

class _IncomeHistory extends StatelessWidget {
  const _IncomeHistory({required this.records});
  final List<IncomeRecord> records;

  @override
  Widget build(BuildContext context) {
    final yearly = IncomeReport.totalsByYear(records).entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final cumulative = IncomeReport.total(records);
    final maxYearly = yearly.fold<int>(
      0,
      (max, entry) => entry.value > max ? entry.value : max,
    );

    return _ReportSection(
      title: '수입의 역사',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in yearly)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(width: 48, child: Text(entry.key.toString())),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: maxYearly == 0 ? 0 : entry.value / maxYearly,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_won(entry.value)),
                ],
              ),
            ),
          const Divider(height: 24),
          Text(
            '기록 시작 후 누적 수입',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            _won(cumulative),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _CompositionRow extends StatelessWidget {
  const _CompositionRow({
    required this.label,
    required this.amount,
    required this.ratio,
  });

  final String label;
  final int amount;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(_won(amount)),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                child: Text(
                  _percent(ratio),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: ratio.clamp(0.0, 1.0)),
        ],
      ),
    );
  }
}

class _SimpleAmountRow extends StatelessWidget {
  const _SimpleAmountRow({required this.label, required this.amount});
  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(_won(amount)),
        ],
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport({required this.year});
  final int year;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        child: Center(
          child: Text(year.toString() + '년에 기록된 수입이 없습니다.'),
        ),
      ),
    );
  }
}

String _won(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return (amount < 0 ? '-' : '') + buffer.toString() + '원';
}

String _percent(double ratio) => (ratio * 100).toStringAsFixed(1) + '%';
