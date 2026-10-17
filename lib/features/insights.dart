import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/finance.dart';
import '../core/models.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../shared/widgets.dart';
import '../state/providers.dart';
import 'transaction_details.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key, required this.data, required this.now});
  final AppData data;
  final DateTime now;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodProvider);
    final report = SpendingReport(data, period, now);
    final top = report.categories.isEmpty ? null : report.categories.first;
    final rows = <Widget>[];
    String? previousDate;
    for (final e in report.expenses) {
      if (previousDate != e.expenseDate) {
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 6),
            child: Text(
              e.expenseDate == dateKey(now)
                  ? 'Today'
                  : DateFormat('EEEE, MMM d').format(parseDate(e.expenseDate)),
              style: const TextStyle(
                color: C.secondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        );
        previousDate = e.expenseDate;
      }
      rows.add(
        TransactionRow(
          expense: e,
          category: data.categoryFor(e),
          onTap: () => showTransaction(context, e, data.categoryFor(e)),
        ),
      );
    }
    return CustomScrollView(
      key: const PageStorageKey('insights-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text(S.history, style: heading(20)),
              const SizedBox(height: 6),
              const Text(
                S.insightsIntro,
                style: TextStyle(color: C.secondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F0EC),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    for (final p in Period.values)
                      Expanded(
                        child: Semantics(
                          selected: p == period,
                          button: true,
                          child: TextButton(
                            key: Key('filter-${p.name}'),
                            onPressed: () =>
                                ref.read(periodProvider.notifier).state = p,
                            style: TextButton.styleFrom(
                              backgroundColor: p == period
                                  ? Colors.white
                                  : Colors.transparent,
                              foregroundColor: p == period
                                  ? C.text
                                  : C.secondary,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                vertical: 13,
                                horizontal: 6,
                              ),
                            ),
                            child: Text(
                              p.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  report.range.label,
                  style: const TextStyle(color: C.secondary, fontSize: 12),
                ),
              ),
              const SizedBox(height: 18),
              SpendingBreakdown(report: report),
              if (top != null) ...[
                const SizedBox(height: 14),
                AppCard(
                  color: C.mint,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              categoryIcon(top.category.iconKey),
                              color: C.success,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(S.topSpending, style: heading(14)),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Text(
                        S.topText(top.category.name, period.phrase),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Text(money(top.cents), style: heading(20)),
                          Text(
                            S.percentPeriod(top.percent),
                            style: const TextStyle(
                              fontSize: 12,
                              color: C.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Semantics(
                        label:
                            '${top.category.name}, ${S.percentPeriod(top.percent)}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: top.share,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFD3EAE3),
                            color: C.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SectionHeader(
                S.allTransactions,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: C.mint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${report.expenses.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: C.success,
                    ),
                  ),
                ),
              ),
              if (report.expenses.isEmpty)
                EmptyExpenses(
                  period: true,
                  onAdd: () => ref.read(tabProvider.notifier).state = 1,
                ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => rows[index],
              childCount: rows.length,
            ),
          ),
        ),
      ],
    );
  }
}

class SpendingBreakdown extends StatelessWidget {
  const SpendingBreakdown({super.key, required this.report});
  final SpendingReport report;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.breakdown, style: heading(16)),
        const SizedBox(height: 8),
        Text(
          money(report.totalCents),
          key: const Key('period-total'),
          style: heading(30),
        ),
        const SizedBox(height: 3),
        const Text(
          S.periodTotal,
          style: TextStyle(color: C.secondary, fontSize: 12),
        ),
        const SizedBox(height: 22),
        Semantics(
          label: report.totalCents == 0
              ? S.zeroBreakdown
              : report.categories
                    .map(
                      (c) =>
                          '${c.category.name}: ${money(c.cents)}, ${c.percent}%',
                    )
                    .join('; '),
          child: ExcludeSemantics(
            child: LayoutBuilder(
              builder: (context, constraints) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 14,
                  width: double.infinity,
                  child: report.totalCents == 0
                      ? const ColoredBox(color: C.border)
                      : Row(
                          children: [
                            for (final c in report.categories)
                              SizedBox(
                                key: ValueKey('segment-${c.category.id}'),
                                width: constraints.maxWidth * c.share,
                                height: 14,
                                child: ColoredBox(
                                  color: categoryColor(c.category.colorHex),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (report.totalCents == 0)
          const Text(
            S.zeroBreakdown,
            style: TextStyle(color: C.secondary, fontSize: 13),
          )
        else
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              for (final c in report.categories)
                SizedBox(
                  width: MediaQuery.textScalerOf(context).scale(1) > 1.4
                      ? double.infinity
                      : 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: categoryColor(c.category.colorHex),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.category.name,
                              style: const TextStyle(
                                fontSize: 12,
                                color: C.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${money(c.cents)} · ${c.percent}%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}
