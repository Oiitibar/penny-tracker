import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/finance.dart';
import '../core/models.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../shared/widgets.dart';
import '../state/providers.dart';
import 'expense_form.dart';

Future<void> showTransaction(
  BuildContext context,
  Expense expense,
  Category category,
) async {
  final action = await appSheet<String>(
    context,
    TransactionDetails(expense: expense, category: category),
  );
  if (!context.mounted) return;
  if (action == 'edit') {
    final saved = await appSheet<bool>(context, _EditExpense(expense));
    if (saved == true && context.mounted) feedback(context, S.updated);
  } else if (action == 'deleted') {
    feedback(context, S.deleted);
  }
}

class TransactionDetails extends ConsumerStatefulWidget {
  const TransactionDetails({
    super.key,
    required this.expense,
    required this.category,
  });
  final Expense expense;
  final Category category;
  @override
  ConsumerState<TransactionDetails> createState() => _TransactionDetailsState();
}

class _TransactionDetailsState extends ConsumerState<TransactionDetails> {
  bool _deleting = false;
  String? _error;
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.deleteQuestion(widget.expense.name)),
        content: const Text(S.deleteHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(S.cancel),
          ),
          TextButton(
            key: const Key('confirm-delete'),
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: C.error),
            child: const Text(S.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(appStoreProvider.notifier).delete(widget.expense.id);
      if (mounted) Navigator.pop(context, 'deleted');
    } catch (_) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = S.deleteFailed;
        });
      }
    }
  }

  Widget _detail(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: C.secondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(S.details, style: heading(20))),
              IconButton(
                tooltip: S.close,
                onPressed: _deleting ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(child: CategoryBadge(widget.category, size: 56)),
          const SizedBox(height: 16),
          Text(expense.name, textAlign: TextAlign.center, style: heading(20)),
          const SizedBox(height: 8),
          Text(
            '-${money(expense.amountCents)}',
            textAlign: TextAlign.center,
            style: heading(30, color: C.error),
          ),
          const SizedBox(height: 24),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _detail(S.category, widget.category.name),
                const Divider(height: 1),
                _detail(
                  S.date,
                  DateFormat.yMMMd().format(parseDate(expense.expenseDate)),
                ),
                const Divider(height: 1),
                _detail(
                  S.recordedTime,
                  DateFormat.jms().format(
                    DateTime.parse(
                      '${expense.expenseDate}T${expense.expenseTime}',
                    ),
                  ),
                ),
                const Divider(height: 1),
                _detail(
                  S.payment,
                  expense.paymentMethod == 'cash' ? S.cash : S.card,
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(_error!, style: const TextStyle(color: C.error)),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('edit-transaction'),
            onPressed: _deleting ? null : () => Navigator.pop(context, 'edit'),
            icon: const Icon(Icons.edit_outlined, size: 19),
            label: const Text(S.edit),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('delete-transaction'),
            onPressed: _deleting ? null : _delete,
            style: OutlinedButton.styleFrom(foregroundColor: C.error),
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            label: Text(_deleting ? S.deleting : S.delete),
          ),
        ],
      ),
    );
  }
}

class _EditExpense extends ConsumerWidget {
  const _EditExpense(this.expense);
  final Expense expense;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(appStoreProvider).requireValue;
    return SingleChildScrollView(
      key: const Key('edit-scroll'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(S.editExpense, style: heading(20))),
              IconButton(
                tooltip: S.close,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ExpenseForm(
            data: data,
            now: ref.read(clockProvider)(),
            original: expense,
            onSaved: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }
}
