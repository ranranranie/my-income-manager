import 'package:flutter_test/flutter_test.dart';
import 'package:my_income_manager/src/models/income_models.dart';

void main() {
  test('managed source mapping preserves group, active state and last use', () {
    final source = IncomeSourceEntry.fromMap({
      'id': 3,
      'group_key': 'company',
      'name': '회사A',
      'is_active': 1,
      'last_used_at': '2026-11-27T10:00:00.000',
    });
    expect(source.id, 3);
    expect(source.groupKey, 'company');
    expect(source.name, '회사A');
    expect(source.isActive, isTrue);
    expect(source.lastUsedAt, DateTime(2026, 11, 27, 10));
  });

  test('managed account mapping keeps optional institution and inactive state', () {
    final account = IncomeAccountEntry.fromMap({
      'id': 4,
      'name': 'ISA',
      'institution': '증권사A',
      'is_active': 0,
      'last_used_at': null,
    });
    expect(account.name, 'ISA');
    expect(account.institution, '증권사A');
    expect(account.isActive, isFalse);
    expect(account.lastUsedAt, isNull);
  });
}
