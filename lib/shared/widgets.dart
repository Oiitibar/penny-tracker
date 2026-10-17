import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/finance.dart';
import '../core/models.dart';
import '../core/strings.dart';
import '../core/theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: C.border.withValues(alpha: .7)),
    ),
    child: child,
  );
}

class CategoryBadge extends StatelessWidget {
  const CategoryBadge(this.category, {super.key, this.size = 46});
  final Category category;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: categoryColor(category.colorHex).withValues(alpha: .16),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(
      categoryIcon(category.iconKey),
      color: categoryColor(category.colorHex).withValues(alpha: 1),
      size: 23,
    ),
  );
}

class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.expense,
    required this.category,
    required this.onTap,
  });
  final Expense expense;
  final Category category;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final date = parseDate(expense.expenseDate);
    final time = DateFormat.jm().format(
      DateTime.parse('${expense.expenseDate}T${expense.expenseTime}'),
    );
    return Semantics(
      button: true,
      label:
          '${expense.name}, ${category.name}, ${money(expense.amountCents)}, ${DateFormat.yMMMd().format(date)}, $time',
      child: InkWell(
        key: ValueKey('expense-${expense.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryBadge(category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat('MMM d').format(date)} · $time',
                      style: const TextStyle(color: C.secondary, fontSize: 12),
                    ),
                    if (MediaQuery.textScalerOf(context).scale(1) > 1.4)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '-${money(expense.amountCents)}',
                          style: const TextStyle(
                            color: C.error,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (MediaQuery.textScalerOf(context).scale(1) <= 1.4)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Text(
                    '-${money(expense.amountCents)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: C.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyExpenses extends StatelessWidget {
  const EmptyExpenses({super.key, required this.onAdd, this.period = false});
  final VoidCallback onAdd;
  final bool period;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: C.mint,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.receipt_long_outlined,
            color: C.success,
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        Text(period ? S.noPeriod : S.noExpenses, style: heading(16)),
        const SizedBox(height: 6),
        Text(
          period ? S.noPeriodHelp : S.firstExpense,
          textAlign: TextAlign.center,
          style: const TextStyle(color: C.secondary),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: const Text(S.addExpense),
        ),
      ],
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: heading(16))),
      ?trailing,
    ],
  );
}

void feedback(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

Future<T?> appSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                MediaQuery.sizeOf(context).height * .9 -
                MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: child,
        ),
      ),
    );
