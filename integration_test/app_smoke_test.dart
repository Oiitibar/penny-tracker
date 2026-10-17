import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:student_penny_tracker/app.dart';
import 'package:student_penny_tracker/core/finance.dart';
import 'package:student_penny_tracker/data/database.dart';
import 'package:student_penny_tracker/data/repository.dart';
import 'package:student_penny_tracker/state/providers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native SQLite save, tab navigation and database reopen', (
    tester,
  ) async {
    final now = DateTime.now();
    final path = p.join(await getDatabasesPath(), 'penny-integration-test.db');
    await deleteDatabase(
      path,
    ); // A separate test database; never the user's data.
    var db = AppDatabase(path: path, clock: () => now);
    var repo = SqliteExpenseRepository(db, () => now);
    final before = BudgetSummary(await repo.load(), now);
    Future<void> launch() async {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            clockProvider.overrideWithValue(() => now),
          ],
          child: const PennyTrackerApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    await launch();
    await tester.tap(find.byKey(const Key('nav-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('expense-amount')), '10.00');
    await tester.enterText(
      find.byKey(const Key('expense-name')),
      'Device smoke expense',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.ensureVisible(find.byKey(const Key('save-expense')));
    await tester.tap(find.byKey(const Key('save-expense')));
    await tester.pumpAndSettle();
    expect(find.text('Expense saved successfully.'), findsOneWidget);
    expect(
      BudgetSummary(await repo.load(), now).spentCents,
      before.spentCents + 1000,
    );
    for (final tab in [2, 1, 0]) {
      await tester.tap(find.byKey(Key('nav-$tab')));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
    db = AppDatabase(path: path, clock: () => now);
    repo = SqliteExpenseRepository(db, () => now);
    await launch();
    expect(
      (await repo.load()).expenses.any((e) => e.name == 'Device smoke expense'),
      true,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await db.close();
    await deleteDatabase(path);
  });
}
