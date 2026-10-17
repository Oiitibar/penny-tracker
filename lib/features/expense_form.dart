import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/finance.dart';
import '../core/models.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../state/providers.dart';

/// Shared by the persistent Add tab and the edit bottom sheet.
class ExpenseForm extends ConsumerStatefulWidget {
  const ExpenseForm({
    super.key,
    required this.data,
    required this.now,
    required this.onSaved,
    this.original,
  });
  final AppData data;
  final DateTime now;
  final Expense? original;
  final VoidCallback onSaved;
  @override
  ConsumerState<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends ConsumerState<ExpenseForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController(),
      _name = TextEditingController(),
      _custom = TextEditingController();
  final _amountFocus = FocusNode(),
      _nameFocus = FocusNode(),
      _customFocus = FocusNode();
  late DateTime _date;
  late int _category;
  late String _payment;
  String? _error, _dateError;
  bool _saving = false, _dirty = false;
  bool get _isOther =>
      widget.data.categories
          .firstWhere((c) => c.id == _category)
          .normalizedName ==
      'other';
  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    final e = widget.original;
    _amount.text = e == null ? '' : amountText(e.amountCents);
    _name.text = e?.name ?? '';
    _custom.clear();
    _date = e == null ? calendarDay(widget.now) : parseDate(e.expenseDate);
    _category = e?.categoryId ?? widget.data.categories.first.id;
    if (e != null && widget.data.categoryFor(e).normalizedName == 'other') {
      _custom.text = widget.data.categoryFor(e).name;
    }
    _payment = e?.paymentMethod ?? widget.data.preferences.lastPaymentMethod;
    _error = null;
    _dateError = null;
    _dirty = false;
  }

  @override
  void didUpdateWidget(ExpenseForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dirty && widget.original == null) {
      _date = calendarDay(widget.now);
      _payment = widget.data.preferences.lastPaymentMethod;
    }
  }

  @override
  void dispose() {
    for (final c in [_amount, _name, _custom]) {
      c.dispose();
    }
    for (final f in [_amountFocus, _nameFocus, _customFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  String? _amountError(String? value) {
    try {
      parseCents(value ?? '');
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  Future<void> _pickDate() async {
    final today = calendarDay(ref.read(clockProvider)());
    final selected = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: S.date,
      confirmText: S.chooseDate,
    );
    if (selected != null && mounted) {
      setState(() {
        _date = selected;
        _dateError = null;
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final now = ref.read(clockProvider)();
    final valid = _form.currentState!.validate();
    final dateError = validateDate(dateKey(_date), now);
    setState(() {
      _dateError = dateError;
      _error = null;
    });
    if (!valid || dateError != null) {
      if (_amountError(_amount.text) != null) {
        _amountFocus.requestFocus();
      } else if (_name.text.trim().runes.length > 60) {
        _nameFocus.requestFocus();
      } else if (_isOther && validateCategory(_custom.text) != null) {
        _customFocus.requestFocus();
      }
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await ref
          .read(appStoreProvider.notifier)
          .save(
            ExpenseInput(
              amount: _amount.text,
              name: _name.text,
              categoryId: _category,
              customCategory: _isOther ? _custom.text : null,
              date: dateKey(_date),
              paymentMethod: _payment,
            ),
            original: widget.original,
          );
      if (!mounted) return;
      if (widget.original == null) {
        _form.currentState?.reset();
        _reset();
      }
      setState(() => _saving = false);
      widget.onSaved();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = widget.original == null ? S.saveFailed : S.updateFailed;
        });
      }
    }
  }

  Widget _label(String label, {String? hint}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ),
        if (hint != null)
          Text(hint, style: const TextStyle(color: C.secondary, fontSize: 12)),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final categories = widget.data.categories
        .where((c) => !c.isCustom)
        .toList();
    final customCategories = widget.data.categories
        .where((c) => c.isCustom)
        .toList();
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(S.amount),
          TextFormField(
            key: const Key('expense-amount'),
            controller: _amount,
            focusNode: _amountFocus,
            enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            style: heading(32),
            decoration: const InputDecoration(
              prefixIcon: Padding(
                padding: EdgeInsets.only(left: 20, right: 8),
                child: Text(
                  r'$',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              hintText: '0.00',
              hintStyle: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 32,
                color: Color(0xFF9EADA8),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            validator: _amountError,
            onChanged: (_) => _dirty = true,
            onFieldSubmitted: (_) => _nameFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
          _label(S.expenseName, hint: S.optional),
          TextFormField(
            key: const Key('expense-name'),
            controller: _name,
            focusNode: _nameFocus,
            enabled: !_saving,
            maxLength: 60,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: S.nameHint,
              counterText: '',
            ),
            validator: (v) =>
                (v?.trim().runes.length ?? 0) > 60 ? S.nameTooLong : null,
            onChanged: (_) => _dirty = true,
          ),
          const SizedBox(height: 16),
          _label(S.category),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = MediaQuery.textScalerOf(context).scale(1) > 1.4
                  ? 2
                  : 4;
              return Wrap(
                spacing: 8,
                runSpacing: 10,
                children: [
                  for (final c in categories)
                    SizedBox(
                      width:
                          (constraints.maxWidth - (columns - 1) * 8) / columns,
                      child: _CategoryTile(
                        category: c,
                        selected: _category == c.id,
                        onTap: _saving
                            ? null
                            : () => setState(() {
                                _category = c.id;
                                _dirty = true;
                              }),
                      ),
                    ),
                ],
              );
            },
          ),
          if (customCategories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in customCategories)
                  ChoiceChip(
                    label: Text(c.name),
                    selected: _category == c.id,
                    showCheckmark: true,
                    selectedColor: C.peach,
                    avatar: Icon(categoryIcon(c.iconKey), size: 16),
                    onSelected: _saving
                        ? null
                        : (_) => setState(() {
                            _category = c.id;
                            _dirty = true;
                          }),
                  ),
              ],
            ),
          ],
          if (_isOther) ...[
            const SizedBox(height: 20),
            _label(S.customCategory),
            TextFormField(
              key: const Key('custom-category'),
              controller: _custom,
              focusNode: _customFocus,
              enabled: !_saving,
              decoration: const InputDecoration(hintText: S.customHint),
              textCapitalization: TextCapitalization.words,
              validator: (v) => validateCategory(v ?? ''),
              onChanged: (_) => _dirty = true,
            ),
          ],
          const SizedBox(height: 16),
          _label(S.date),
          Semantics(
            button: true,
            label: 'Expense date, ${DateFormat.yMMMMd().format(_date)}',
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: C.border),
              ),
              child: InkWell(
                key: const Key('expense-date'),
                onTap: _saving ? null : _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 20,
                        color: C.secondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          DateFormat.yMMMMd().format(_date),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: C.secondary,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_dateError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_dateError!, style: const TextStyle(color: C.error)),
            ),
          const SizedBox(height: 16),
          _label(S.payment),
          Row(
            children: [
              for (final method in ['cash', 'card']) ...[
                if (method == 'card') const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    selected: _payment == method,
                    button: true,
                    child: OutlinedButton.icon(
                      key: Key('payment-$method'),
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                              _payment = method;
                              _dirty = true;
                            }),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: _payment == method
                            ? C.mint
                            : Colors.white,
                        side: BorderSide(
                          color: _payment == method ? C.success : C.border,
                          width: _payment == method ? 1.5 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: Icon(
                        _payment == method
                            ? Icons.check_circle_outline
                            : method == 'cash'
                            ? Icons.payments_outlined
                            : Icons.credit_card_outlined,
                        size: 20,
                      ),
                      label: Text(method == 'cash' ? S.cash : S.card),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  key: const Key('save-error'),
                  style: const TextStyle(color: C.error),
                ),
              ),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('save-expense'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: C.text,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 21),
              label: Text(
                _saving
                    ? S.saving
                    : widget.original == null
                    ? S.saveExpense
                    : S.saveChanges,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });
  final Category category;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: category.name,
    child: Material(
      color: selected ? C.peach : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? const Color(0xFFCF8045) : C.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        key: Key('category-${category.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    categoryIcon(category.iconKey),
                    color: selected ? const Color(0xFF96501E) : C.secondary,
                    size: 24,
                  ),
                  if (selected)
                    const Positioned(
                      right: -12,
                      top: -6,
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 13,
                        color: Color(0xFF96501E),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                category.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? const Color(0xFF80491F) : C.secondary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AddExpenseScreen extends StatelessWidget {
  const AddExpenseScreen({
    super.key,
    required this.data,
    required this.now,
    required this.onSaved,
  });
  final AppData data;
  final DateTime now;
  final VoidCallback onSaved;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const PageStorageKey('add-scroll'),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.addExpense, style: heading(20)),
        const SizedBox(height: 6),
        const Text(
          S.addIntro,
          style: TextStyle(color: C.secondary, fontSize: 14),
        ),
        const SizedBox(height: 16),
        ExpenseForm(data: data, now: now, onSaved: onSaved),
      ],
    ),
  );
}
