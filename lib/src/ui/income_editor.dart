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
  final _scrollController = ScrollController();
  final _amountKey = GlobalKey();
  final _sourceKey = GlobalKey();
  final _accountKey = GlobalKey();

  IncomeType type = IncomeType.salary;
  DateTime date = DateTime.now();
  bool saving = false;
  bool memoExpanded = false;
  bool validationAttempted = false;
  bool amountError = false;
  bool sourceError = false;
  bool accountError = false;

  bool get isEditing => widget.record != null;
  bool get sourceRequired => type == IncomeType.dividend;
  bool get accountVisible =>
      type == IncomeType.dividend || type == IncomeType.interest;
  bool get accountRequired => type == IncomeType.dividend;

  int? get parsedAmount {
    final value = int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
    return value != null && value > 0 ? value : null;
  }

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    if (record != null) {
      amount.text = _formatDigits(record.amount);
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
    _scrollController.dispose();
    super.dispose();
  }

  void _addAmount(int delta) {
    if (saving) return;
    final current =
        int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    amount.text = _formatDigits(current + delta);
    amount.selection = TextSelection.collapsed(offset: amount.text.length);
    _refreshValidation();
  }

  void _changeType(IncomeType next) {
    if (saving || next == type) return;
    setState(() {
      type = next;
      if (validationAttempted) _updateErrors();
    });
  }

  void _onAmountChanged(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    final formatted =
        digits.isEmpty ? '' : _formatDigits(int.tryParse(digits) ?? 0);
    if (formatted != value) {
      amount.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    _refreshValidation();
  }

  void _refreshValidation() {
    setState(() {
      if (validationAttempted) _updateErrors();
    });
  }

  void _updateErrors() {
    amountError = parsedAmount == null;
    sourceError = sourceRequired && source.text.trim().isEmpty;
    accountError =
        accountRequired && accountVisible && account.text.trim().isEmpty;
  }

  bool _validate() {
    setState(() {
      validationAttempted = true;
      _updateErrors();
    });
    if (!amountError && !sourceError && !accountError) return true;

    final target = amountError
        ? _amountKey
        : sourceError
            ? _sourceKey
            : _accountKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = target.currentContext;
      if (mounted && targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: 0.2,
        );
      }
    });
    return false;
  }

  Future<void> _deleteRecord() async {
    if (!isEditing || saving || widget.record?.id == null) return;
    FocusScope.of(context).unfocus();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('수입 기록을 삭제할까요?'),
        content: const Text('삭제한 기록은 목록에서 제거됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => saving = true);
    try {
      await IncomeDatabase.instance.delete(widget.record!.id!);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickDate() async {
    if (saving) return;
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted) return;
    if (picked != null) setState(() => date = picked);
  }

  Future<void> save() async {
    if (saving || !_validate()) return;
    setState(() => saving = true);

    final now = DateTime.now();
    final record = IncomeRecord(
      id: widget.record?.id,
      amount: parsedAmount!,
      date: date,
      type: type,
      source: source.text.trim().isEmpty ? null : source.text.trim(),
      account: accountVisible && account.text.trim().isNotEmpty
          ? account.text.trim()
          : null,
      memo: memo.text.trim().isEmpty ? null : memo.text.trim(),
      createdAt: widget.record?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      if (record.id == null) {
        await IncomeDatabase.instance.insert(record);
      } else {
        await IncomeDatabase.instance.update(record);
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<bool> _onWillPop() async => !saving;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '뒤로',
            onPressed: saving ? null : () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(isEditing ? '수입 수정' : '수입 기록'),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
                  children: [
                    const _FieldLabel(text: '날짜', required: true),
                    const SizedBox(height: 7),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: saving ? null : _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_month_outlined),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 15,
                          ),
                        ),
                        child: Text(_dateLabel(date)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _FieldLabel(text: '수입 유형', required: true),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: IncomeType.values
                          .map(
                            (item) => ChoiceChip(
                              label: Text(item.label),
                              selected: type == item,
                              onSelected:
                                  saving ? null : (_) => _changeType(item),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    const _FieldLabel(text: '금액', required: true),
                    const SizedBox(height: 7),
                    TextField(
                      key: _amountKey,
                      controller: amount,
                      autofocus: !isEditing,
                      enabled: !saving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,]')),
                      ],
                      textInputAction: TextInputAction.done,
                      onChanged: _onAmountChanged,
                      decoration: InputDecoration(
                        hintText: '금액을 입력하세요.',
                        suffixText: '원',
                        errorText: amountError ? '금액을 입력해주세요.' : null,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
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
                        _AmountAction(
                          label: '+1만',
                          enabled: !saving,
                          onPressed: () => _addAmount(10000),
                        ),
                        _AmountAction(
                          label: '+5만',
                          enabled: !saving,
                          onPressed: () => _addAmount(50000),
                        ),
                        _AmountAction(
                          label: '+10만',
                          enabled: !saving,
                          onPressed: () => _addAmount(100000),
                        ),
                        _AmountAction(
                          label: '+50만',
                          enabled: !saving,
                          onPressed: () => _addAmount(500000),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _ConditionalFields(
                      type: type,
                      sourceController: source,
                      accountController: account,
                      sourceRequired: sourceRequired,
                      accountVisible: accountVisible,
                      accountRequired: accountRequired,
                      sourceError: sourceError,
                      accountError: accountError,
                      sourceKey: _sourceKey,
                      accountKey: _accountKey,
                      enabled: !saving,
                      onChanged: _refreshValidation,
                    ),
                    const _FieldLabel(text: '메모', optional: true),
                    const SizedBox(height: 7),
                    TextField(
                      controller: memo,
                      enabled: !saving,
                      minLines: 2,
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: '메모를 입력하세요.',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isEditing) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton(
                          onPressed: saving ? null : _deleteRecord,
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(context).colorScheme.error,
                          ),
                          child: const Text('수입 기록 삭제'),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            saving ? null : () => Navigator.maybePop(context),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 13),
                          child: Text('취소'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: saving ? null : save,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Text(saving ? '저장 중…' : '저장'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    required this.sourceError,
    required this.accountError,
    required this.sourceKey,
    required this.accountKey,
    required this.enabled,
    required this.onChanged,
  });

  final IncomeType type;
  final TextEditingController sourceController;
  final TextEditingController accountController;
  final bool sourceRequired;
  final bool accountVisible;
  final bool accountRequired;
  final bool sourceError;
  final bool accountError;
  final GlobalKey sourceKey;
  final GlobalKey accountKey;
  final bool enabled;
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
        _FieldLabel(text: sourceLabel, required: sourceRequired, optional: !sourceRequired),
        const SizedBox(height: 7),
        TextField(
          key: sourceKey,
          controller: sourceController,
          enabled: enabled,
          onChanged: (_) => onChanged(),
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: sourceRequired ? '수입원을 입력하세요.' : '수입원을 입력하세요.',
            errorText: sourceError ? '수입원을 입력해주세요.' : null,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          ),
        ),
        if (accountVisible) ...[
          const SizedBox(height: 16),
          _FieldLabel(
            text: 'Account',
            required: accountRequired,
            optional: !accountRequired,
          ),
          const SizedBox(height: 7),
          TextField(
            key: accountKey,
            controller: accountController,
            enabled: enabled,
            onChanged: (_) => onChanged(),
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              hintText: '일반계좌, ISA, 연금저축, IRP',
              errorText: accountError ? '계좌를 입력해주세요.' : null,
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

class _AmountAction extends StatelessWidget {
  const _AmountAction({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(58, 40),
      ),
      child: Text(label),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.text,
    this.required = false,
    this.optional = false,
  });

  final String text;
  final bool required;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final suffix = required
        ? ' *'
        : optional
            ? ' (선택)'
            : '';
    return Text(
      text + suffix,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

String _formatDigits(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String _dateLabel(DateTime value) {
  final now = DateTime.now();
  final sameDay =
      now.year == value.year && now.month == value.month && now.day == value.day;
  final date =
      '${value.year}년 ${value.month}월 ${value.day}일';
  return sameDay ? '$date (오늘)' : date;
}
