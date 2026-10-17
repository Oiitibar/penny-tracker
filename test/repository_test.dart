import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:student_penny_tracker/core/finance.dart';
import 'package:student_penny_tracker/core/models.dart';
import 'package:student_penny_tracker/data/database.dart';
import 'package:student_penny_tracker/data/repository.dart';

void main() {
  sqfliteFfiInit();
  late Directory temp;
  late AppDatabase db;
  late SqliteExpenseRepository repo;
  var now = DateTime(2026, 10, 15, 8, 2);
  ExpenseInput input({
    String amount = '10.00',
    int category = 1,
    String? custom,
    String date = '2026-10-15',
    String payment = 'card',
    String name = '',
  }) => ExpenseInput(
    amount: amount,
    name: name,
    categoryId: category,
    customCategory: custom,
    date: date,
    paymentMethod: payment,
  );
  setUp(() async {
    now = DateTime(2026, 10, 15, 8, 2);
    temp = await Directory.systemTemp.createTemp('penny-db-');
    db = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: '${temp.path}/tracker.db',
      clock: () => now,
    );
    repo = SqliteExpenseRepository(db, () => now);
  });
  tearDown(() async {
    await db.close();
    await temp.delete(recursive: true);
  });
  test('first creation seeds exact data and enables foreign keys', () async {
    final d = await repo.load();
    expect(d.categories.length, 8);
    expect(d.expenses.length, 4);
    expect(d.expenses.fold(0, (int sum, e) => sum + e.amountCents), 12065);
    expect(d.preferences.weeklyBudgetCents, 57500);
    expect(d.preferences.lastPaymentMethod, 'cash');
    expect(
      d.expenses.where((e) => e.expenseDate == dateKey(now)).single.expenseTime,
      '08:02:00',
    );
    expect(
      (await (await db.open()).rawQuery(
        'PRAGMA foreign_keys',
      )).single.values.single,
      1,
    );
    expect(await (await db.open()).getVersion(), AppDatabase.schemaVersion);
  });
  test('adds exactly 1000 cents and persists local date and payment', () async {
    final before = BudgetSummary(await repo.load(), now);
    final d = await repo.save(input());
    final after = BudgetSummary(d, now);
    expect(after.spentCents - before.spentCents, 1000);
    expect(after.remainingCents - before.remainingCents, -1000);
    final added = d.expenses.firstWhere((e) => e.id == 5);
    expect(added.name, 'Food expense');
    expect(added.paymentMethod, 'card');
    expect(added.expenseDate, '2026-10-15');
    expect(d.preferences.lastPaymentMethod, 'card');
  });
  test('custom names are normalized and existing categories reused', () async {
    await repo.save(input(category: 8, custom: '  Campus   Printing  '));
    var d = await repo.save(input(category: 8, custom: 'campus PRINTING'));
    expect(d.categories.length, 9);
    expect(d.categories.last.name, 'Campus Printing');
    expect(
      d.expenses.where((e) => e.categoryId == d.categories.last.id).length,
      2,
    );
    d = await repo.save(input(category: 8, custom: ' FOOD '));
    expect(d.categories.length, 9);
    expect(d.expenses.firstWhere((e) => e.id == 7).categoryId, 1);
  });
  test('predefined selection ignores unsaved custom text', () async {
    final d = await repo.save(input(category: 2, custom: 'Do not create'));
    expect(d.categories.length, 8);
    expect(d.expenses.firstWhere((e) => e.id == 5).categoryId, 2);
  });
  test('failed expense insert rolls back custom category and payment', () async {
    await repo.load();
    await (await db.open()).execute(
      "CREATE TRIGGER simulate_full_disk BEFORE INSERT ON expenses BEGIN SELECT RAISE(ABORT, 'simulated write failure'); END",
    );
    await expectLater(
      repo.save(input(category: 8, custom: 'Printing')),
      throwsA(anything),
    );
    final d = await repo.load();
    expect(d.expenses.length, 4);
    expect(d.categories.length, 8);
    expect(d.preferences.lastPaymentMethod, 'cash');
  });
  test('editing preserves id, original time and creation timestamp', () async {
    final original = (await repo.load()).expenses.first;
    now = DateTime(2026, 10, 16, 15);
    final d = await repo.save(
      input(
        amount: '12.34',
        name: 'Updated lunch',
        date: '2026-10-01',
        payment: 'cash',
      ),
      original: original,
    );
    final edited = d.expenses.singleWhere((e) => e.id == original.id);
    expect(edited.expenseTime, original.expenseTime);
    expect(edited.createdAtUtc, original.createdAtUtc);
    expect(edited.updatedAtUtc, now.toUtc().toIso8601String());
    expect(edited.amountCents, 1234);
    expect(
      SpendingReport(
        d,
        Period.week,
        now,
      ).expenses.any((e) => e.id == original.id),
      false,
    );
  });
  test(
    'deleting recalculates totals and missing id does not succeed',
    () async {
      final before = await repo.load();
      final target = before.expenses.first;
      final after = await repo.delete(target.id);
      expect(after.expenses.length, 3);
      expect(
        BudgetSummary(after, now).spentCents,
        BudgetSummary(before, now).spentCents - target.amountCents,
      );
      await expectLater(repo.delete(target.id), throwsStateError);
    },
  );
  test(
    'data, custom colors, budget, payment and dismissed notice survive restart',
    () async {
      var d = await repo.save(input(category: 8, custom: 'Printing'));
      final color = d.categories.last.colorHex;
      await repo.setBudget('600.25');
      await repo.dismissSampleNotice();
      await db.close();
      now = DateTime(2027, 1, 1);
      d = await repo.load();
      expect(d.expenses.length, 5);
      expect(d.categories.last.colorHex, color);
      expect(d.preferences.weeklyBudgetCents, 60025);
      expect(d.preferences.lastPaymentMethod, 'card');
      expect(d.preferences.sampleNoticeDismissed, true);
      expect(d.expenses.any((e) => e.expenseDate == '2027-01-01'), false);
    },
  );
  test('deleting every transaction stays empty after a full restart', () async {
    for (final e in (await repo.load()).expenses) {
      await repo.delete(e.id);
    }
    await db.close();
    now = DateTime(2027, 1, 1);
    final d = await repo.load();
    expect(d.expenses, isEmpty);
    expect(d.categories.length, 8);
  });
  test(
    'invalid financial, category, date and payment inputs never persist',
    () async {
      final invalid = [
        input(amount: '0'),
        input(amount: '-1'),
        input(amount: '1.001'),
        input(amount: '1000000'),
        input(category: 8, custom: ' '),
        input(date: '2026-10-16'),
        input(payment: 'bitcoin'),
        input(category: 999),
        input(name: 'a' * 61),
      ];
      for (final i in invalid) {
        await expectLater(repo.save(i), throwsFormatException);
      }
      expect((await repo.load()).expenses.length, 4);
    },
  );
}
