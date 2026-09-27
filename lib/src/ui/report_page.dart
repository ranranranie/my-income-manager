import 'dart:math' as math;

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
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
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
              const SizedBox(height: 18),
              _TypeComposition(records: selectedRecords),
              const SizedBox(height: 18),
              _SourceComposition(records: selectedRecords),
              const SizedBox(height: 18),
              _FinancialIncome(records: selectedRecords),
            ],
            if (allRecords.isNotEmpty) ...[
              const SizedBox(height: 18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('연간 총수입', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 5),
          _AmountText(_won(total), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: _Metric(label: '기록 월 수', value: '$months개월')),
            const SizedBox(width: 16),
            Expanded(child: _Metric(label: '월평균 수입', value: _won(average))),
          ]),
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
    final entries = [for (final type in IncomeType.values) if ((values[type] ?? 0) > 0) MapEntry(type, values[type]!)];

    return _ReportSection(
      title: '수입 유형별 구성',
      child: Column(
        children: [
          Center(child: _IncomeDonut(entries: entries, total: total)),
          const SizedBox(height: 18),
          for (final entry in entries)
            _CompositionRow(markerColor: _typeColor(entry.key), label: entry.key.label, amount: entry.value, ratio: IncomeReport.ratio(entry.value, total)),
          const Divider(height: 24),
          _SupportingValue(label: '월급 외 수입', amount: nonSalary, ratio: IncomeReport.ratio(nonSalary, total)),
        ],
      ),
    );
  }
}

class _IncomeDonut extends StatelessWidget {
  const _IncomeDonut({required this.entries, required this.total});
  final List<MapEntry<IncomeType, int>> entries;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190, height: 190,
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: _DonutPainter(values: entries.map((e) => e.value).toList(), colors: entries.map((e) => _typeColor(e.key)).toList())),
        Center(child: SizedBox(width: 112, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('총 수입', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          _AmountText(_won(total), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ]))),
      ]),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});
  final List<int> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    if (total <= 0) return;
    final strokeWidth = math.min(size.width, size.height) * 0.16;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: radius);
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = math.pi * 2 * (values[i] / total);
      canvas.drawArc(rect, start, sweep, false, Paint()..color = colors[i]..style = PaintingStyle.stroke..strokeWidth = strokeWidth);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.values != values || oldDelegate.colors != colors;
}

class _SourceComposition extends StatelessWidget {
  const _SourceComposition({required this.records});
  final List<IncomeRecord> records;

  @override
  Widget build(BuildContext context) {
    final total = IncomeReport.total(records);
    final entries = IncomeReport.bySource(records).entries.toList()..sort((a, b) {
      final byAmount = b.value.compareTo(a.value);
      return byAmount != 0 ? byAmount : a.key.compareTo(b.key);
    });
    const visibleCount = 5;
    final visible = entries.take(visibleCount).toList();
    final otherAmount = entries.skip(visibleCount).fold<int>(0, (sum, entry) => sum + entry.value);

    return _ReportSection(
      title: '수입원별 구성',
      child: Column(children: [
        if (entries.isEmpty)
          const Align(alignment: Alignment.centerLeft, child: Text('수입원이 입력된 기록이 없습니다.'))
        else ...[
          for (final entry in visible)
            _SourceRow(source: entry.key, typeLabel: _sourceTypeLabel(records, entry.key), amount: entry.value, ratio: IncomeReport.ratio(entry.value, total)),
          if (otherAmount > 0)
            _SourceRow(source: '기타 수입원', typeLabel: '여러 유형', amount: otherAmount, ratio: IncomeReport.ratio(otherAmount, total)),
        ],
      ]),
    );
  }
}

String _sourceTypeLabel(List<IncomeRecord> records, String source) {
  final types = <IncomeType>{};
  for (final record in records) {
    if (record.source?.trim() == source) types.add(record.type);
  }
  return types.length == 1 ? types.single.label : (types.isEmpty ? '' : '여러 유형');
}

class _FinancialIncome extends StatelessWidget {
  const _FinancialIncome({required this.records});
  final List<IncomeRecord> records;

  @override
  Widget build(BuildContext context) {
    final total = IncomeReport.total(records);
    final byType = IncomeReport.byType(records);
    final dividend = byType[IncomeType.dividend] ?? 0;
    final interest = byType[IncomeType.interest] ?? 0;
    final financial = IncomeReport.financialIncome(records);

    return _ReportSection(
      title: '금융소득',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _AmountText(_won(financial), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text('전체 수입의 '+_percent(IncomeReport.ratio(financial, total)), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        _CompositionRow(label: '배당', amount: dividend, ratio: IncomeReport.ratio(dividend, total)),
        _CompositionRow(label: '이자', amount: interest, ratio: IncomeReport.ratio(interest, total)),
        const SizedBox(height: 8),
        Text('금융소득은 배당과 이자의 합계입니다.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _IncomeHistory extends StatelessWidget {
  const _IncomeHistory({required this.records});
  final List<IncomeRecord> records;

  @override
  Widget build(BuildContext context) {
    final yearly = IncomeReport.totalsByYear(records).entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final cumulative = IncomeReport.total(records);
    final maxYearly = yearly.fold<int>(0, (max, entry) => entry.value > max ? entry.value : max);

    return _ReportSection(
      title: '수입의 역사',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('연도별 총수입', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 10),
        for (final entry in yearly) _HistoryRow(year: entry.key, amount: entry.value, fraction: maxYearly == 0 ? 0 : entry.value / maxYearly),
        const Divider(height: 26),
        Text('기록 시작 후 누적 수입', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 5),
        _AmountText(_won(cumulative), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.year, required this.amount, required this.fraction});
  final int year;
  final int amount;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(children: [
        Row(children: [
          Text(year.toString(), style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Expanded(child: _AmountText(_won(amount), textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(minHeight: 8, value: fraction.clamp(0.0, 1.0).toDouble())),
      ]),
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 5),
      _AmountText(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
    ]);
  }
}

class _CompositionRow extends StatelessWidget {
  const _CompositionRow({this.markerColor, required this.label, required this.amount, required this.ratio});
  final Color? markerColor;
  final String label;
  final int amount;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        if (markerColor != null) ...[
          Container(width: 9, height: 9, decoration: BoxDecoration(color: markerColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
        const SizedBox(width: 8),
        Flexible(child: _AmountText(_won(amount), textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodyMedium)),
        const SizedBox(width: 6),
        SizedBox(width: 48, child: Text(_percent(ratio), textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      ]),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.typeLabel, required this.amount, required this.ratio});
  final String source;
  final String typeLabel;
  final int amount;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(source, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (typeLabel.isNotEmpty) Text(typeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
        const SizedBox(width: 8),
        Expanded(flex: 4, child: _AmountText(_won(amount), textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodyMedium)),
        const SizedBox(width: 6),
        SizedBox(width: 48, child: Text(_percent(ratio), textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      ]),
    );
  }
}

class _SupportingValue extends StatelessWidget {
  const _SupportingValue({required this.label, required this.amount, required this.ratio});
  final String label;
  final int amount;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 3, children: [
      Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      Text(_won(amount)),
      Text('전체의 '+_percent(ratio), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
  }
}

class _AmountText extends StatelessWidget {
  const _AmountText(this.text, {this.style, this.textAlign = TextAlign.left});
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(text, maxLines: 1, overflow: TextOverflow.fade, softWrap: false, textAlign: textAlign, style: style);
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

Color _typeColor(IncomeType type) => switch (type) {
  IncomeType.salary => const Color(0xff806d4f),
  IncomeType.bonus => const Color(0xffb58a57),
  IncomeType.dividend => const Color(0xff68856d),
  IncomeType.interest => const Color(0xff6f8297),
  IncomeType.sideJob => const Color(0xff987487),
  IncomeType.appTech => const Color(0xff9a8c5c),
  IncomeType.other => const Color(0xff8b8177),
};

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
