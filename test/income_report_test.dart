import 'package:flutter_test/flutter_test.dart';
import 'package:my_income_manager/src/models/income_models.dart';
import 'package:my_income_manager/src/report/income_report.dart';

IncomeRecord record(int amount, DateTime date, IncomeType type, {String? source}) {
  return IncomeRecord(
    amount: amount,
    date: date,
    type: type,
    source: source,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  final records = [
    record(3000000, DateTime(2026, 1, 25), IncomeType.salary, source: '회사A'),
    record(100000, DateTime(2026, 1, 28), IncomeType.dividend, source: 'ETF A'),
    record(50000, DateTime(2026, 2, 10), IncomeType.interest, source: '예금'),
    record(200000, DateTime(2025, 12, 1), IncomeType.sideJob, source: '외주'),
  ];

  test('monthly totals include every month and preserve recorded sums', () {
    final selected = records.where((e) => e.date.year == 2026);
    final totals = IncomeReport.totalsByMonth(selected);
    expect(totals.length, 12);
    expect(totals[1], 3100000);
    expect(totals[2], 50000);
    expect(totals[3], 0);
  });

  test('monthly activity filters year and month and counts non salary records', () {
    final january = IncomeReport.forMonth(records, 2026, 1);
    expect(january.length, 2);
    expect(IncomeReport.nonSalaryRecordCount(january), 1);
  });

  test('yearly totals remain based on existing income records', () {
    expect(IncomeReport.totalsByYear(records), {2026: 3150000, 2025: 200000});
  });
}
