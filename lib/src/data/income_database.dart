import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/income_models.dart';
class IncomeDatabase {
 IncomeDatabase._(); static final instance=IncomeDatabase._(); static const schemaVersion=1; Database? _database;
 Future<Database> get database async=>_database??=await _open();
 Future<Database> _open() async {final p=join(await getDatabasesPath(),'my_income_manager.db');return openDatabase(p,version:schemaVersion,onCreate:(db,v) async {await db.execute('CREATE TABLE income_records(id INTEGER PRIMARY KEY AUTOINCREMENT, amount INTEGER NOT NULL, date TEXT NOT NULL, type TEXT NOT NULL, source TEXT, account TEXT, memo TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)');await db.execute('CREATE INDEX idx_income_date ON income_records(date DESC)');await db.execute('CREATE INDEX idx_income_type ON income_records(type)');});}
 Future<int> insert(IncomeRecord r) async=>(await database).insert('income_records',r.toMap()..remove('id'));
 Future<List<IncomeRecord>> all() async=>(await (await database).query('income_records',orderBy:'date DESC, id DESC')).map(IncomeRecord.fromMap).toList();
 Future<List<IncomeRecord>> forYear(int y) async {final start=y.toString()+'-01-01T00:00:00.000';final end=(y+1).toString()+'-01-01T00:00:00.000';final rows=await (await database).query('income_records',where:'date >= ? AND date < ?',whereArgs:[start,end],orderBy:'date DESC, id DESC');return rows.map(IncomeRecord.fromMap).toList();}
 Future<void> update(IncomeRecord r) async {if(r.id==null)throw ArgumentError('record.id is required');await (await database).update('income_records',r.toMap()..remove('id'),where:'id = ?',whereArgs:[r.id]);}
 Future<void> delete(int id) async=>(await database).delete('income_records',where:'id = ?',whereArgs:[id]);
}
