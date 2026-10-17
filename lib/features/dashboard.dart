import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/finance.dart';
import '../core/models.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../shared/widgets.dart';
import '../state/providers.dart';
import 'budget_editor.dart';
import 'transaction_details.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.data, required this.now});
  final AppData data;
  final DateTime now;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = BudgetSummary(data, now);
    final recent = [...data.expenses]..sort(compareExpenses);
    void add() => ref.read(tabProvider.notifier).state = 1;
    return CustomScrollView(
      key: const PageStorageKey('home-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: C.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.savings_outlined,
                      size: 22,
                      color: C.text,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(S.appName, style: heading(18))),
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: C.peach,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF3DEC8)),
                    ),
                    child: const Text(
                      'C',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8C5636),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(S.greeting, style: heading(25)),
              const SizedBox(height: 7),
              const Text(
                S.intro,
                style: TextStyle(color: C.secondary, fontSize: 14),
              ),
              const SizedBox(height: 22),
              _BudgetCard(budget: budget, now: now),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: C.blue,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: C.navy,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            S.spentWeek,
                            style: TextStyle(color: C.secondary, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(money(budget.spentCents), style: heading(24)),
                          const SizedBox(height: 3),
                          Text(
                            S.weeklyLimit(money(budget.budgetCents)),
                            style: const TextStyle(
                              color: C.secondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                color: C.mint,
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      budget.remainingCents < 0
                          ? Icons.info_outline_rounded
                          : Icons.wb_sunny_outlined,
                      size: 22,
                      color: C.success,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            budget.remainingCents < 0
                                ? S.overBudgetTitle
                                : S.dailyTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            budget.guidance,
                            style: const TextStyle(
                              color: C.secondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionHeader(
                S.recent,
                trailing: TextButton(
                  onPressed: () {
                    ref.read(periodProvider.notifier).state = Period.week;
                    ref.read(tabProvider.notifier).state = 2;
                  },
                  child: const Text(S.viewAll),
                ),
              ),
              if (recent.isEmpty)
                AppCard(child: EmptyExpenses(onAdd: add))
              else
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < recent.take(3).length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: C.border),
                        TransactionRow(
                          expense: recent[i],
                          category: data.categoryFor(recent[i]),
                          onTap: () => showTransaction(
                            context,
                            recent[i],
                            data.categoryFor(recent[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              if (!data.preferences.sampleNoticeDismissed) ...[
                const SizedBox(height: 16),
                AppCard(
                  color: C.peach,
                  padding: const EdgeInsets.fromLTRB(14, 10, 4, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.auto_awesome_outlined,
                          color: Color(0xFF92613C),
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.sampleTitle,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              S.sampleText,
                              style: TextStyle(
                                color: Color(0xFF795B48),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: S.dismissSamples,
                        onPressed: () async {
                          try {
                            await ref
                                .read(appStoreProvider.notifier)
                                .dismissSampleNotice();
                          } catch (_) {
                            if (context.mounted) {
                              feedback(context, S.saveFailed);
                            }
                          }
                        },
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  S.localOnly,
                  style: TextStyle(color: C.secondary, fontSize: 11),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget, required this.now});
  final DateTime now;
  final BudgetSummary budget;
  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          S.budgetLeft,
          style: TextStyle(
            color: C.secondary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          budget.remainingCents < 0
              ? S.overBudget(money(-budget.remainingCents))
              : money(budget.remainingCents),
          style: heading(
            budget.remainingCents < 0 ? 23 : 32,
            color: budget.remainingCents < 0 ? C.error : C.text,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: budget.remainingCents <= 0 ? C.peach : C.green,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                budget.remainingCents <= 0
                    ? Icons.info_outline
                    : Icons.check_circle_outline,
                size: 14,
                color: budget.remainingCents <= 0
                    ? const Color(0xFF8B5533)
                    : C.success,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  budget.status,
                  style: TextStyle(
                    color: budget.remainingCents <= 0
                        ? const Color(0xFF8B5533)
                        : C.success,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final ring = Semantics(
      label: S.remainingDescription(budget.remainingPercent),
      child: ExcludeSemantics(
        child: SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 94,
                height: 94,
                child: CircularProgressIndicator(
                  value: budget.remainingRatio,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                  backgroundColor: C.mint,
                  color: C.primary,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${budget.remainingPercent}%', style: heading(23)),
                  const Text(
                    S.remainingLabel,
                    style: TextStyle(color: C.secondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (MediaQuery.textScalerOf(context).scale(1) > 1.4) ...[
            content,
            const SizedBox(height: 20),
            Center(child: ring),
          ] else
            Row(
              children: [
                Expanded(child: content),
                const SizedBox(width: 12),
                ring,
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  dateRange(Period.week, now).label,
                  style: const TextStyle(fontSize: 11, color: C.secondary),
                ),
              ),
              TextButton.icon(
                onPressed: () => editBudget(context, budget.budgetCents),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text(S.editBudget, style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
