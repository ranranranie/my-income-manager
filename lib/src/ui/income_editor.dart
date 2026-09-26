import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/income_database.dart';
import '../models/income_models.dart';

class IncomeEditor extends StatefulWidget {
  const IncomeEditor({super.key, this.record});

  final IncomeRecord? record;

  @override
  State<IncomeEditor> createState() => _IncomeEditorState();
}

class _IncomeEditorState extends State<IncomeEditor> {
  final amount = TextEditingController();
  final source = TextEditingController();
  final account = TextEditingController();
  final memo = TextEditingController();

  IncomeType type = IncomeType.salary;
  DateTime date = DateTime.now();
  bool saving = false;
  bool memoExpanded = false;

  bool get isEditing => widget.record != null;
  bool get sourceRequired => type == IncomeType.dividend;
  bool get accountVisible =>
      type == IncomeType.dividend || type == IncomeType.interest;
  bool get accountRequired => type == IncomeType.dividend;

  int? get parsedAmount {
    final value = int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
    return value != null && value > 0 ? value : null;
  }

  bool get canSave =>
      !saving &&
      parsedAmount != null &&
      (!sourceRequired || source.text.trim().isNotEmpty) &&
      (!accountRequired || account.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    if (record != null) {
      amount.text = record.amount.toString();
      source.text = record.source ?? '';
      account.text = record.account ?? '';
      memo.text = record.memo ?? '';
      type = record.type;
      date = record.date;
      memoExpanded = record.memo?.isNotEmpty ?? false;
    }
  }

  @override
  void dispose() {
    amount.dispose();
    source.dispose();
    account.dispose();
    memo.dispose();
    super.dispose();
  }

  void _addAmount(int delta) {
    final current =
        int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    amount.text = (current + delta).toString();
    amount.selection = TextSelection.collapsed(offset: amount.text.length);
    setState(() {});
  }

  void _changeType(IncomeType next) {
    if (next == type) return;
    setState(() => type = next);
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => date = picked);
  }

  Future<void> save() async {
    if (!canSave) return;
    setState(() => saving = true);

    final now = DateTime.now();
    final record = IncomeRecord(
      id: widget.record?.id,
      amount: parsedAmount!,
      date: date,
      type: type,
      source: source.text.trim().isEmpty ? null : source.text.trim(),
      account: account.text.trim().isEmpty ? null : account.text.trim(),
      memo: memo.text.trim().isEmpty ? null : memo.text.trim(),
      createdAt: widget.record?.createdAt ?? now,
      updatedAt: now,
    );

    if (record.id == null) {
      await IncomeDatabase.instance.insert(record);
    } else {
      await IncomeDatabase.instance.update(record);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '수입 수정' : '수입 기록'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
          children: [
            _SectionLabel(text: '금액'),
            const SizedBox(height: 7),
            TextField(
              controller: amount,
              autofocus: !isEditing,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '0',
                suffixText: '원',
                border: OutlineInputBorder(),
              ),
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _AmountAction(label: '+1만', onPressed: () => _addAmount(10000)),
                _AmountAction(label: '+5만', onPressed: () => _addAmount(50000)),
                _AmountAction(label: '+10만', onPressed: () => _addAmount(100000)),
                _AmountAction(label: '+50만', onPressed: () => _addAmount(500000)),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(text: '수입 유형'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: IncomeType.values
                  .map(
                    (item) => ChoiceChip(
                      label: Text(item.label),
                      selected: type == item,
                      onSelected: (_) => _changeType(item),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            _ConditionalFields(
              type: type,
              sourceController: source,
              accountController: account,
              sourceRequired: sourceRequired,
              accountVisible: accountVisible,
              accountRequired: accountRequired,
              onChanged: () => setState(() {}),
            ),
            _SectionLabel(text: '날짜'),
            const SizedBox(height: 7),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_month_outlined),
                ),
                child: Text(_dateLabel(date)),
              ),
            ),
            const SizedBox(height: 12),
            if (!memoExpanded)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => memoExpanded = true),
                  icon: const Icon(Icons.notes, size: 18),
                  label: const Text('메모 (선택)'),
                ),
              )
            else
              TextField(
                controller: memo,
                maxLines: 2,
                minLines: 1,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: '메모 (선택)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: '메모 접기',
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      setState(() => memoExpanded = false);
                    },
                    icon: const Icon(Icons.expand_less),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: canSave ? save : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Text(saving ? '저장 중…' : '저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConditionalFields extends StatelessWidget {
  const _ConditionalFields({
    required this.type,
    required this.sourceController,
    required this.accountController,
    required this.sourceRequired,
    required this.accountVisible,
    required this.accountRequired,
    required this.onChanged,
  });

  final IncomeType type;
  final TextEditingController sourceController;
  final TextEditingController accountController;
  final bool sourceRequired;
  final bool accountVisible;
  final bool accountRequired;
  final VoidCallback onChanged;

  String get sourceLabel => switch (type) {
        IncomeType.salary || IncomeType.bonus => '회사 / Source',
        IncomeType.dividend => '종목·상품 / Source',
        IncomeType.interest => '상품 / Source',
        IncomeType.sideJob => 'Source',
        IncomeType.appTech => '앱·서비스 / Source',
        IncomeType.other => 'Source',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: '수입 정보'),
        const SizedBox(height: 7),
        TextField(
          controller: sourceController,
          onChanged: (_) => onChanged(),
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: sourceRequired ? sourceLabel + ' *' : sourceLabel + ' (선택)',
            border: const OutlineInputBorder(),
          ),
        ),
        if (accountVisible) ...[
          const SizedBox(height: 10),
          TextField(
            controller: accountController,
            onChanged: (_) => onChanged(),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: accountRequired ? 'Account *' : 'Account (선택)',
              hintText: '일반계좌, ISA, 연금저축, IRP',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _AmountAction extends StatelessWidget {
  const _AmountAction({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(58, 40),
      ),
      child: Text(label),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

String _dateLabel(DateTime value) {
  final now = DateTime.now();
  final sameDay =
      now.year == value.year && now.month == value.month && now.day == value.day;
  if (sameDay) return '오늘';
  return value.year.toString() +
      '.' +
      value.month.toString().padLeft(2, '0') +
      '.' +
      value.day.toString().padLeft(2, '0');
}
