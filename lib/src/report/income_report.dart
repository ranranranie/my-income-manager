import '../models/income_models.dart';

class IncomeReport {
  IncomeReport._();

  static int total(Iterable<IncomeRecord> records) =>
      records.fold(0, (sum, record) => sum + record.amount);

  static Set<int> recordedMonths(Iterable<IncomeRecord> records) =>
      records.map((record) => record.date.month).toSet();

  static int activeMonthAverage(Iterable<IncomeRecord> records) {
    final list = records.toList();
    final months = recordedMonths(list).length;
    return months == 0 ? 0 : total(list) ~/ months;
  }

  static Map<IncomeType, int> byType(Iterable<IncomeRecord> records) {
    final result = <IncomeType, int>{};
    for (final record in records) {
      result[record.type] = (result[record.type] ?? 0) + record.amount;
    }
    return result;
  }

  static Map<String, int> bySource(Iterable<IncomeRecord> records) {
    final result = <String, int>{};
    for (final record in records) {
      final source = record.source?.trim();
      if (source == null || source.isEmpty) continue;
      result[source] = (result[source] ?? 0) + record.amount;
    }
    return result;
  }

  static int nonSalaryIncome(Iterable<IncomeRecord> records) =>
      records
          .where((record) =>
              record.type != IncomeType.salary &&
              record.type != IncomeType.bonus)
          .fold(0, (sum, record) => sum + record.amount);

  static int financialIncome(Iterable<IncomeRecord> records) =>
      records
          .where((record) =>
              record.type == IncomeType.dividend ||
              record.type == IncomeType.interest)
          .fold(0, (sum, record) => sum + record.amount);

  static Map<int, int> totalsByYear(Iterable<IncomeRecord> records) {
    final result = <int, int>{};
    for (final record in records) {
      result[record.date.year] = (result[record.date.year] ?? 0) + record.amount;
    }
    return result;
  }

  static double ratio(int amount, int totalAmount) =>
      totalAmount == 0 ? 0 : amount / totalAmount;
}
