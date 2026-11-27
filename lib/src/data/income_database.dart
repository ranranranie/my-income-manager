import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/income_models.dart';

class IncomeDatabase {
  IncomeDatabase._();
  static final instance = IncomeDatabase._();
  static const schemaVersion = 2;

  static Future<void> upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await _createManagementTables(db);
      await _importExistingManagementValues(db);
    }
  }
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final p = join(await getDatabasesPath(), 'my_income_manager.db');
    return openDatabase(
      p,
      version: schemaVersion,
      onCreate: (db, v) async {
        await _createRecords(db);
        await _createManagementTables(db);
      },
      onUpgrade: upgradeSchema,
    );
  }

  Future<void> _createRecords(Database db) async {
    await db.execute('CREATE TABLE income_records(id INTEGER PRIMARY KEY AUTOINCREMENT, amount INTEGER NOT NULL, date TEXT NOT NULL, type TEXT NOT NULL, source TEXT, account TEXT, memo TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');
    await db.execute('CREATE INDEX idx_income_date ON income_records(date DESC)');
    await db.execute('CREATE INDEX idx_income_type ON income_records(type)');
  }

  static Future<void> _createManagementTables(Database db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS income_sources(id INTEGER PRIMARY KEY AUTOINCREMENT, group_key TEXT NOT NULL, name TEXT NOT NULL COLLATE NOCASE, is_active INTEGER NOT NULL DEFAULT 1, last_used_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, UNIQUE(group_key, name))');
    await db.execute('CREATE TABLE IF NOT EXISTS income_accounts(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL COLLATE NOCASE UNIQUE, institution TEXT, is_active INTEGER NOT NULL DEFAULT 1, last_used_at TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');
  }

  static Future<void> _importExistingManagementValues(Database db) async {
    final now = DateTime.now().toIso8601String();
    final rows = await db.query('income_records', columns: ['type', 'source', 'account', 'date']);
    for (final row in rows) {
      final type = row['type'] as String;
      final source = (row['source'] as String?)?.trim();
      final account = (row['account'] as String?)?.trim();
      final usedAt = row['date'] as String?;
      if (source != null && source.isNotEmpty) {
        await db.rawInsert(
          'INSERT OR IGNORE INTO income_sources(group_key,name,is_active,last_used_at,created_at,updated_at) VALUES(?,?,1,?,?,?)',
          [_sourceGroupName(type), source, usedAt, now, now],
        );
      }
      if (account != null && account.isNotEmpty) {
        await db.rawInsert(
          'INSERT OR IGNORE INTO income_accounts(name,institution,is_active,last_used_at,created_at,updated_at) VALUES(?,NULL,1,?,?,?)',
          [account, usedAt, now, now],
        );
      }
    }
  }

  static String _sourceGroupName(String typeName) =>
      typeName == IncomeType.salary.name || typeName == IncomeType.bonus.name ? 'company' : typeName;

  Future<int> insert(IncomeRecord r) async {
    final db = await database;
    final id = await db.insert('income_records', r.toMap()..remove('id'));
    await _touchSelections(db, r);
    return id;
  }

  Future<List<IncomeRecord>> all() async =>
      (await (await database).query('income_records', orderBy: 'date DESC, id DESC')).map(IncomeRecord.fromMap).toList();

  Future<List<IncomeRecord>> forYear(int y) async {
    final start = '$y-01-01T00:00:00.000';
    final end = '${y + 1}-01-01T00:00:00.000';
    final rows = await (await database).query('income_records', where: 'date >= ? AND date < ?', whereArgs: [start, end], orderBy: 'date DESC, id DESC');
    return rows.map(IncomeRecord.fromMap).toList();
  }

  Future<void> update(IncomeRecord r) async {
    if (r.id == null) throw ArgumentError('record.id is required');
    final db = await database;
    await db.update('income_records', r.toMap()..remove('id'), where: 'id = ?', whereArgs: [r.id]);
    await _touchSelections(db, r);
  }

  Future<void> delete(int id) async => (await database).delete('income_records', where: 'id = ?', whereArgs: [id]);

  Future<void> _touchSelections(Database db, IncomeRecord record) async {
    final now = DateTime.now().toIso8601String();
    final source = record.source?.trim();
    if (source != null && source.isNotEmpty) {
      final group = _sourceGroupName(record.type.name);
      await db.rawInsert('INSERT OR IGNORE INTO income_sources(group_key,name,is_active,last_used_at,created_at,updated_at) VALUES(?,?,1,?,?,?)', [group, source, now, now, now]);
      await db.update('income_sources', {'is_active': 1, 'last_used_at': now, 'updated_at': now}, where: 'group_key = ? AND name = ?', whereArgs: [group, source]);
    }
    final account = record.account?.trim();
    if (account != null && account.isNotEmpty) {
      await db.rawInsert('INSERT OR IGNORE INTO income_accounts(name,institution,is_active,last_used_at,created_at,updated_at) VALUES(?,NULL,1,?,?,?)', [account, now, now, now]);
      await db.update('income_accounts', {'is_active': 1, 'last_used_at': now, 'updated_at': now}, where: 'name = ?', whereArgs: [account]);
    }
  }

  Future<List<IncomeSourceEntry>> sourcesFor(IncomeType type, {bool includeInactive = false}) async {
    final group = _sourceGroupName(type.name);
    final rows = await (await database).query('income_sources', where: includeInactive ? 'group_key = ?' : 'group_key = ? AND is_active = 1', whereArgs: [group], orderBy: 'last_used_at IS NULL, last_used_at DESC, name COLLATE NOCASE');
    return rows.map(IncomeSourceEntry.fromMap).toList();
  }

  Future<List<IncomeSourceEntry>> allSources() async {
    final rows = await (await database).query('income_sources', orderBy: 'group_key, is_active DESC, name COLLATE NOCASE');
    return rows.map(IncomeSourceEntry.fromMap).toList();
  }

  Future<int> addSource(IncomeType type, String name) async {
    final value = name.trim();
    if (value.isEmpty) throw ArgumentError('name is required');
    final now = DateTime.now().toIso8601String();
    return (await database).insert('income_sources', {'group_key': _sourceGroupName(type.name), 'name': value, 'is_active': 1, 'created_at': now, 'updated_at': now}, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> renameSource(IncomeSourceEntry entry, String newName) async {
    final value = newName.trim();
    if (value.isEmpty) throw ArgumentError('name is required');
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('income_sources', {'name': value, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [entry.id]);
      final types = entry.groupKey == 'company' ? [IncomeType.salary.name, IncomeType.bonus.name] : [entry.groupKey];
      final placeholders = List.filled(types.length, '?').join(',');
      await txn.rawUpdate('UPDATE income_records SET source = ? WHERE source = ? AND type IN ($placeholders)', [value, entry.name, ...types]);
    });
  }

  Future<void> setSourceActive(int id, bool active) async =>
      (await database).update('income_sources', {'is_active': active ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);

  Future<List<IncomeAccountEntry>> accounts({bool includeInactive = false}) async {
    final rows = await (await database).query('income_accounts', where: includeInactive ? null : 'is_active = 1', orderBy: 'last_used_at IS NULL, last_used_at DESC, name COLLATE NOCASE');
    return rows.map(IncomeAccountEntry.fromMap).toList();
  }

  Future<int> addAccount(String name, String? institution) async {
    final value = name.trim();
    if (value.isEmpty) throw ArgumentError('name is required');
    final now = DateTime.now().toIso8601String();
    return (await database).insert('income_accounts', {'name': value, 'institution': institution?.trim().isEmpty == true ? null : institution?.trim(), 'is_active': 1, 'created_at': now, 'updated_at': now}, conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<void> updateAccount(IncomeAccountEntry entry, String name, String? institution) async {
    final value = name.trim();
    if (value.isEmpty) throw ArgumentError('name is required');
    final db = await database;
    await db.transaction((txn) async {
      await txn.update('income_accounts', {'name': value, 'institution': institution?.trim().isEmpty == true ? null : institution?.trim(), 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [entry.id]);
      if (value != entry.name) {
        await txn.update('income_records', {'account': value}, where: 'account = ?', whereArgs: [entry.name]);
      }
    });
  }

  Future<void> setAccountActive(int id, bool active) async =>
      (await database).update('income_accounts', {'is_active': active ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
}
