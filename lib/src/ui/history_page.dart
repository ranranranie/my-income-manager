import 'package:flutter/material.dart';

import '../data/income_database.dart';
import '../models/income_models.dart';
import 'income_editor.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.revision,
    required this.onChanged,
  });

  final int revision;
  final VoidCallback onChanged;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _searchController = TextEditingController();
  String query = '';
  IncomeType? filter;

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;

    return FutureBuilder<List<IncomeRecord>>(
      key: ValueKey(widget.revision),
      future: IncomeDatabase.instance.all(),
      builder: (context, snapshot) {
        final allRecords = snapshot.data ?? const <IncomeRecord>[];
        final normalizedQuery = query.trim().toLowerCase();

        final records = allRecords.where((record) {
          final searchable = (
            record.type.label +
            ' ' +
            (record.source ?? '') +
            ' ' +
            (record.account ?? '') +
            ' ' +
            (record.memo ?? '')
          ).toLowerCase();
          return (filter == null || record.type == filter) &&
              searchable.contains(normalizedQuery);
        }).toList();

        final groups = _groupByMonth(records);
        final hasActiveCondition = normalizedQuery.isNotEmpty || filter != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Income Manager',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currentYear.toString() + '년',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => query = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: '회사명, 종목, 메모로 검색',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '검색어 지우기',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => query = '');
                              },
                              icon: const Icon(Icons.close, size: 19),
                            ),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _FilterChip(
                          label: '전체',
                          selected: filter == null,
                          onSelected: () => setState(() => filter = null),
                        ),
                        for (final type in IncomeType.values) ...[
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: type.label,
                            selected: filter == type,
                            onSelected: () => setState(() => filter = type),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: allRecords.isEmpty
                  ? const _HistoryEmptyState(
                      title: '아직 기록된 수입이 없어요.',
                    )
                  : records.isEmpty && hasActiveCondition
                      ? const _HistoryEmptyState(
                          title: '조건에 맞는 수입 기록이 없어요.',
                          detail: '다른 검색어를 사용하거나 필터를 변경해보세요.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                          itemCount: groups.length,
                          itemBuilder: (context, index) {
                            final group = groups[index];
                            return _MonthSection(
                              group: group,
                              typeColors: _typeColors,
                              onOpen: _openRecord,
                              onDelete: _deleteRecord,
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openRecord(IncomeRecord record) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => IncomeEditor(record: record)),
    );
    if (changed == true && mounted) {
      widget.onChanged();
      setState(() {});
    }
  }

  Future<void> _deleteRecord(IncomeRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('기록 삭제'),
        content: const Text('이 수입 기록을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (ok == true && record.id != null) {
      await IncomeDatabase.instance.delete(record.id!);
      if (mounted) {
        widget.onChanged();
        setState(() {});
      }
    }
  }
}

class _MonthGroup {
  const _MonthGroup({
    required this.year,
    required this.month,
    required this.records,
  });

  final int year;
  final int month;
  final List<IncomeRecord> records;
}

List<_MonthGroup> _groupByMonth(List<IncomeRecord> records) {
  final groups = <_MonthGroup>[];
  for (final record in records) {
    if (groups.isEmpty ||
        groups.last.year != record.date.year ||
        groups.last.month != record.date.month) {
      groups.add(
        _MonthGroup(
          year: record.date.year,
          month: record.date.month,
          records: <IncomeRecord>[record],
        ),
      );
    } else {
      groups.last.records.add(record);
    }
  }
  return groups;
}

class _MonthSection extends StatelessWidget {
  const _MonthSection({
    required this.group,
    required this.typeColors,
    required this.onOpen,
    required this.onDelete,
  });

  final _MonthGroup group;
  final Map<IncomeType, Color> typeColors;
  final ValueChanged<IncomeRecord> onOpen;
  final ValueChanged<IncomeRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.year.toString() + '년 ' + group.month.toString() + '월',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                group.records.length.toString() + '건',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          for (final record in group.records)
            _IncomeHistoryRow(
              record: record,
              color: typeColors[record.type]!,
              onTap: () => onOpen(record),
              onLongPress: () => onDelete(record),
            ),
        ],
      ),
    );
  }
}

class _IncomeHistoryRow extends StatelessWidget {
  const _IncomeHistoryRow({
    required this.record,
    required this.color,
    required this.onTap,
    required this.onLongPress,
  });

  final IncomeRecord record;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final source = record.source?.trim();
    final primary = source == null || source.isEmpty ? record.type.label : source;
    final account = record.account?.trim();
    final secondary = account == null || account.isEmpty
        ? record.type.label
        : record.type.label + ' · ' + account;
    final memo = record.memo?.trim();

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 42,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    record.date.month.toString() +
                        '.' +
                        record.date.day.toString(),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(
                    '(' + _weekdayLabel(record.date.weekday) + ')',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    primary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          secondary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                      if (memo != null && memo.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Icon(
                          Icons.notes,
                          size: 13,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 72),
              child: Text(
                _formatWon(record.amount),
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState({required this.title, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center),
            if (detail != null) ...[
              const SizedBox(height: 5),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _weekdayLabel(int weekday) => switch (weekday) {
      DateTime.monday => '월',
      DateTime.tuesday => '화',
      DateTime.wednesday => '수',
      DateTime.thursday => '목',
      DateTime.friday => '금',
      DateTime.saturday => '토',
      DateTime.sunday => '일',
      _ => '',
    };

String _formatWon(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return (amount < 0 ? '-' : '') + buffer.toString() + '원';
}
