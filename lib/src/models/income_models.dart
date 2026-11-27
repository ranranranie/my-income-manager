enum IncomeType { salary, bonus, dividend, interest, sideJob, appTech, other }
extension IncomeTypeLabel on IncomeType {
 String get label => switch(this){IncomeType.salary=>'급여',IncomeType.bonus=>'상여',IncomeType.dividend=>'배당',IncomeType.interest=>'이자',IncomeType.sideJob=>'부업',IncomeType.appTech=>'앱테크',IncomeType.other=>'기타'};
}
class IncomeRecord {
 const IncomeRecord({this.id,required this.amount,required this.date,required this.type,this.source,this.account,this.memo,required this.createdAt,required this.updatedAt});
 final int? id; final int amount; final DateTime date; final IncomeType type; final String? source; final String? account; final String? memo; final DateTime createdAt; final DateTime updatedAt;
 Map<String,Object?> toMap()=>{'id':id,'amount':amount,'date':date.toIso8601String(),'type':type.name,'source':source,'account':account,'memo':memo,'created_at':createdAt.toIso8601String(),'updated_at':updatedAt.toIso8601String()};
 factory IncomeRecord.fromMap(Map<String,Object?> m)=>IncomeRecord(id:m['id'] as int?,amount:m['amount'] as int,date:DateTime.parse(m['date'] as String),type:IncomeType.values.byName(m['type'] as String),source:m['source'] as String?,account:m['account'] as String?,memo:m['memo'] as String?,createdAt:DateTime.parse(m['created_at'] as String),updatedAt:DateTime.parse(m['updated_at'] as String));
}


class IncomeSourceEntry {
  const IncomeSourceEntry({required this.id, required this.groupKey, required this.name, required this.isActive, this.lastUsedAt});
  final int id;
  final String groupKey;
  final String name;
  final bool isActive;
  final DateTime? lastUsedAt;
  factory IncomeSourceEntry.fromMap(Map<String,Object?> m) => IncomeSourceEntry(
    id: m['id'] as int,
    groupKey: m['group_key'] as String,
    name: m['name'] as String,
    isActive: (m['is_active'] as int) == 1,
    lastUsedAt: m['last_used_at'] == null ? null : DateTime.parse(m['last_used_at'] as String),
  );
}

class IncomeAccountEntry {
  const IncomeAccountEntry({required this.id, required this.name, this.institution, required this.isActive, this.lastUsedAt});
  final int id;
  final String name;
  final String? institution;
  final bool isActive;
  final DateTime? lastUsedAt;
  factory IncomeAccountEntry.fromMap(Map<String,Object?> m) => IncomeAccountEntry(
    id: m['id'] as int,
    name: m['name'] as String,
    institution: m['institution'] as String?,
    isActive: (m['is_active'] as int) == 1,
    lastUsedAt: m['last_used_at'] == null ? null : DateTime.parse(m['last_used_at'] as String),
  );
}
