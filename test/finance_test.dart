import 'package:flutter_test/flutter_test.dart';
import 'package:student_penny_tracker/core/finance.dart';
import 'package:student_penny_tracker/core/models.dart';

Category category(int id, String name) => Category(
  id: id,
  name: name,
  normalizedName: name.toLowerCase(),
  isCustom: false,
  iconKey: 'other',
  colorHex: '#4ECDC4',
);
Expense expense(
  int id,
  int cents,
  String date, {
  int categoryId = 1,
  String time = '09:00:00',
}) => Expense(
  id: id,
  name: 'Test expense',
  amountCents: cents,
  categoryId: categoryId,
  expenseDate: date,
  expenseTime: time,
  paymentMethod: 'cash',
  createdAtUtc: '2026-01-01T00:00:00.000Z',
  updatedAtUtc: '2026-01-01T00:00:00.000Z',
);
AppData data(List<Expense> expenses, {int budget = 57500}) => AppData(
  expenses: expenses,
  categories: [
    category(1, 'Food'),
    category(2, 'Transport'),
    category(3, 'Study'),
  ],
  preferences: Preferences(weeklyBudgetCents: budget),
);

void main() {
  group('Validated cents', () {
    test('parses directly without floating point rounding', () {
      expect(parseCents('0.01'), 1);
      expect(parseCents('4.50'), 450);
      expect(parseCents('10'), 1000);
      expect(parseCents('0001.2'), 120);
      expect(parseCents('999999.99'), 99999999);
    });
    for (final invalid in [
      '',
      '0',
      '0.00',
      '-2',
      'NaN',
      'Infinity',
      '1e2',
      '1,000',
      '1.234',
      '1.000',
      '1..2',
      '4.5a',
      '1000000',
      '999999.999',
      '.50',
      '1.',
      '9' * 1000,
    ]) {
      test(
        'rejects ${invalid.length > 20 ? 'oversized paste' : '“$invalid”'}',
        () => expect(() => parseCents(invalid), throwsFormatException),
      );
    }
    test('specific validation messages', () {
      expect(
        () => parseCents('1.234'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('two decimal'),
          ),
        ),
      );
      expect(
        () => parseCents('1000000'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('999,999.99'),
          ),
        ),
      );
    });
  });
  group('Local calendar periods', () {
    test('Monday inclusive and following Monday exclusive', () {
      final r = dateRange(Period.week, DateTime(2026, 10, 18, 23, 59));
      expect(dateKey(r.start), '2026-10-12');
      expect(dateKey(r.end), '2026-10-19');
      expect(r.contains('2026-10-11'), false);
      expect(r.contains('2026-10-12'), true);
      expect(r.contains('2026-10-18'), true);
      expect(r.contains('2026-10-19'), false);
    });
    test('week crosses year and month boundaries', () {
      final r = dateRange(Period.week, DateTime(2026, 1, 1));
      expect(dateKey(r.start), '2025-12-29');
      expect(dateKey(r.end), '2026-01-05');
    });
    test('month crosses year, leap days are valid', () {
      final r = dateRange(Period.month, DateTime(2025, 12, 31));
      expect(dateKey(r.end), '2026-01-01');
      expect(dateKey(parseDate('2024-02-29')), '2024-02-29');
      expect(() => parseDate('2026-02-29'), throwsFormatException);
      expect(() => parseDate('2026-13-01'), throwsFormatException);
    });
    test('future and invalid dates rejected', () {
      expect(validateDate('2026-10-19', DateTime(2026, 10, 18)), isNotNull);
      expect(validateDate('2026-10-18', DateTime(2026, 10, 18)), isNull);
      expect(validateDate('bad', DateTime(2026)), isNotNull);
    });
    test(
      'midnight changes today and current week without changing records',
      () {
        final records = data([expense(1, 1000, '2026-10-18')]);
        expect(
          SpendingReport(
            records,
            Period.today,
            DateTime(2026, 10, 18, 23, 59),
          ).totalCents,
          1000,
        );
        expect(
          SpendingReport(
            records,
            Period.today,
            DateTime(2026, 10, 19),
          ).totalCents,
          0,
        );
        expect(BudgetSummary(records, DateTime(2026, 10, 19)).spentCents, 0);
        expect(records.expenses.single.expenseDate, '2026-10-18');
      },
    );
  });
  group('Budget and breakdown', () {
    test('required arithmetic and adding exactly 1000 cents', () {
      final records = [
        expense(1, 450, '2026-10-15'),
        expense(2, 275, '2026-10-14', categoryId: 2),
        expense(3, 2840, '2026-10-13'),
        expense(4, 8500, '2026-10-12', categoryId: 3),
      ];
      final before = BudgetSummary(data(records), DateTime(2026, 10, 15));
      expect(before.spentCents, 12065);
      expect(before.remainingCents, 45435);
      expect(before.remainingPercent, 79);
      final after = BudgetSummary(
        data([...records, expense(5, 1000, '2026-10-15')]),
        DateTime(2026, 10, 15),
      );
      expect(after.spentCents - before.spentCents, 1000);
      expect(after.remainingCents - before.remainingCents, -1000);
    });
    test('backdated expense does not consume current allowance', () {
      final b = BudgetSummary(
        data([expense(1, 1000, '2026-10-11')]),
        DateTime(2026, 10, 15),
      );
      expect(b.spentCents, 0);
    });
    test('thresholds, exact allowance, overspending and zero', () {
      for (final pair in [
        (0, 'On track'),
        (43125, 'On track'),
        (43126, 'Getting low'),
        (57500, 'Budget used'),
        (60000, 'Over budget'),
      ]) {
        final b = BudgetSummary(
          data(pair.$1 == 0 ? [] : [expense(1, pair.$1, '2026-10-18')]),
          DateTime(2026, 10, 18),
        );
        expect(b.status, pair.$2);
        expect(b.remainingRatio, inInclusiveRange(0, 1));
        expect(b.daysLeft, 1);
      }
    });
    test('filters share one subset and percentages sum to 100', () {
      final d = data([
        expense(1, 1, '2026-10-18'),
        expense(2, 1, '2026-10-18', categoryId: 2),
        expense(3, 1, '2026-10-18', categoryId: 3),
        expense(4, 1000, '2026-10-01'),
      ]);
      final r = SpendingReport(d, Period.week, DateTime(2026, 10, 18));
      expect(r.totalCents, 3);
      expect(r.expenses.length, 3);
      expect(r.categories.map((c) => c.percent).toList(), [34, 33, 33]);
      expect(r.categories.first.category.name, 'Food');
      expect(r.categories.map((c) => c.percent).reduce((a, b) => a + b), 100);
      expect(
        SpendingReport(d, Period.month, DateTime(2026, 10, 18)).totalCents,
        1003,
      );
    });
    test('empty breakdown has no shares or top category', () {
      final r = SpendingReport(data([]), Period.week, DateTime(2026, 10, 18));
      expect(r.categories, isEmpty);
      expect(r.totalCents, 0);
    });
    test('ordering uses local time then audit timestamp then id', () {
      final r = SpendingReport(
        data([
          expense(1, 100, '2026-10-18'),
          expense(2, 100, '2026-10-18'),
          expense(3, 100, '2026-10-18', time: '10:00:00'),
        ]),
        Period.today,
        DateTime(2026, 10, 18),
      );
      expect(r.expenses.map((e) => e.id), [3, 2, 1]);
    });
    test('category normalization', () {
      expect(normalizedCategoryName('  Campus   PRINTING '), 'campus printing');
      expect(validateCategory(' '), isNotNull);
      expect(validateCategory('a' * 25), isNotNull);
    });
  });
}
