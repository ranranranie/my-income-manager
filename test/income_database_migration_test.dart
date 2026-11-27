import 'package:flutter_test/flutter_test.dart';
import 'package:my_income_manager/src/data/income_database.dart';
import 'package:my_income_manager/src/models/income_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  test('v1 to v2 migration preserves records and imports managed values', () async {
    final db = await factory.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE income_records(id INTEGER PRIMARY KEY AUTOINCREMENT, amount INTEGER NOT NULL, date TEXT NOT NULL, type TEXT NOT NULL, source TEXT, account TEXT, memo TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');
    await db.insert('income_records', {
      'amount': 120000,
      'date': '2026-11-01T00:00:00.000',
      'type': 'dividend',
      'source': 'ETF A',
      'account': 'ISA',
      'memo': '기존 기록',
      'created_at': '2026-11-01T00:00:00.000',
      'updated_at': '2026-11-01T00:00:00.000',
    });

    await IncomeDatabase.upgradeSchema(db, 1, 2);

    final records = await db.query('income_records');
    expect(records, hasLength(1));
    expect(records.single['id'], 1);
    expect(records.single['date'], '2026-11-01T00:00:00.000');
    expect(records.single['type'], 'dividend');
    expect(records.single['amount'], 120000);
    expect(records.single['source'], 'ETF A');
    expect(records.single['account'], 'ISA');
    expect(records.single['memo'], '기존 기록');
    expect(records.single['created_at'], '2026-11-01T00:00:00.000');
    expect(records.single['updated_at'], '2026-11-01T00:00:00.000');

    final sources = await db.query('income_sources');
    expect(sources, hasLength(1));
    expect(sources.single['group_key'], 'dividend');
    expect(sources.single['name'], 'ETF A');

    final accounts = await db.query('income_accounts');
    expect(accounts, hasLength(1));
    expect(accounts.single['name'], 'ISA');
    await db.close();
  });

  test('salary and bonus sources migrate into the shared company group without deleting records', () async {
    final db = await factory.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE income_records(id INTEGER PRIMARY KEY AUTOINCREMENT, amount INTEGER NOT NULL, date TEXT NOT NULL, type TEXT NOT NULL, source TEXT, account TEXT, memo TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');
    for (final type in ['salary', 'bonus']) {
      await db.insert('income_records', {
        'amount': 100,
        'date': '2026-11-01T00:00:00.000',
        'type': type,
        'source': '회사A',
        'account': null,
        'memo': null,
        'created_at': '2026-11-01T00:00:00.000',
        'updated_at': '2026-11-01T00:00:00.000',
      });
    }

    await IncomeDatabase.upgradeSchema(db, 1, 2);
    expect((await db.query('income_records')).length, 2);
    final sources = await db.query('income_sources');
    expect(sources, hasLength(1));
    expect(sources.single['group_key'], 'company');
    expect(sources.single['name'], '회사A');
    await db.close();
  });

  test('renaming managed values updates linked records while deactivation preserves history', () async {
    final db = await factory.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE income_records(id INTEGER PRIMARY KEY AUTOINCREMENT, amount INTEGER NOT NULL, date TEXT NOT NULL, type TEXT NOT NULL, source TEXT, account TEXT, memo TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');
    await IncomeDatabase.upgradeSchema(db, 1, 2);
    final database = IncomeDatabase.forTesting(db);
    final now = DateTime(2026, 11, 27);
    await database.insert(IncomeRecord(amount: 1000, date: now, type: IncomeType.dividend, source: 'ETF A', account: 'ISA', createdAt: now, updatedAt: now));

    final source = (await database.sourcesFor(IncomeType.dividend)).single;
    final account = (await database.accounts()).single;
    await database.renameSource(source, 'ETF B');
    await database.updateAccount(account, '연금저축', '증권사A');
    await database.setSourceActive(source.id, false);
    await database.setAccountActive(account.id, false);

    final record = (await database.all()).single;
    expect(record.source, 'ETF B');
    expect(record.account, '연금저축');
    expect(await database.sourcesFor(IncomeType.dividend), isEmpty);
    expect(await database.accounts(), isEmpty);
    expect(await database.sourcesFor(IncomeType.dividend, includeInactive: true), hasLength(1));
    expect(await database.accounts(includeInactive: true), hasLength(1));
    expect((await database.all()).single.amount, 1000);
    expect((await database.all()).single.date, now);
    await db.close();
  });
}
