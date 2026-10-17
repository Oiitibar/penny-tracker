import '../core/strings.dart';
import 'package:sqflite/sqflite.dart';
import '../core/finance.dart';
import '../core/models.dart';
import 'database.dart';

abstract interface class ExpenseRepository {
  Future<AppData> load();
  Future<AppData> save(ExpenseInput input, {Expense? original});
  Future<AppData> delete(int id);
  Future<AppData> setBudget(String amount);
  Future<AppData> dismissSampleNotice();
}

class SqliteExpenseRepository implements ExpenseRepository {
  SqliteExpenseRepository(this.database, this.clock);
  final AppDatabase database;
  final AppClock clock;

  Future<AppData> _read(DatabaseExecutor db) async => AppData(
    expenses: (await db.query(
      'expenses',
      orderBy: 'expenseDate DESC, expenseTime DESC, createdAtUtc DESC, id DESC',
    )).map(Expense.fromMap).toList(),
    categories: (await db.query(
      'categories',
      orderBy: 'id',
    )).map(Category.fromMap).toList(),
    preferences: Preferences.fromMap(
      (await db.query('preferences', where: 'id = ?', whereArgs: [1])).single,
    ),
  );
  @override
  Future<AppData> load() async => (await database.open()).transaction(_read);

  @override
  Future<AppData> save(ExpenseInput input, {Expense? original}) async {
    final now = clock();
    final cents = parseCents(input.amount);
    final dateError = validateDate(input.date, now);
    if (dateError != null) throw FormatException(dateError);
    if (!['cash', 'card'].contains(input.paymentMethod)) {
      throw const FormatException(S.choosePayment);
    }
    if (input.name.trim().runes.length > 60) {
      throw const FormatException(S.nameTooLong);
    }
    final db = await database.open();
    return db.transaction((txn) async {
      var matches = await txn.query(
        'categories',
        where: 'id = ?',
        whereArgs: [input.categoryId],
      );
      if (matches.isEmpty) throw const FormatException(S.chooseCategory);
      var category = Category.fromMap(matches.single);
      // Unsaved custom text is relevant only when Other is actively selected.
      if (category.normalizedName == 'other' && input.customCategory != null) {
        final categoryError = validateCategory(input.customCategory!);
        if (categoryError != null) throw FormatException(categoryError);
        final clean = cleanCategoryName(input.customCategory!);
        final normalized = normalizedCategoryName(clean);
        matches = await txn.query(
          'categories',
          where: 'normalizedName = ?',
          whereArgs: [normalized],
        );
        if (matches.isEmpty) {
          final hash = normalized.codeUnits.fold(
            0,
            (int h, int unit) => ((h * 31) + unit) & 0x7fffffff,
          );
          final id = await txn.insert('categories', {
            'name': clean,
            'normalizedName': normalized,
            'isCustom': 1,
            'iconKey': 'other',
            'colorHex': customColors[hash % customColors.length],
          });
          matches = await txn.query(
            'categories',
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        category = Category.fromMap(matches.single);
      }
      final stamp = now.toUtc().toIso8601String();
      final name = input.name.trim().isEmpty
          ? S.defaultExpense(category.name)
          : input.name.trim();
      final values = <String, Object?>{
        'name': name,
        'amountCents': cents,
        'categoryId': category.id,
        'expenseDate': input.date,
        'expenseTime': original?.expenseTime ?? timeKey(now),
        'paymentMethod': input.paymentMethod,
        'createdAtUtc': original?.createdAtUtc ?? stamp,
        'updatedAtUtc': stamp,
      };
      if (original == null) {
        await txn.insert('expenses', values);
      } else {
        final changed = await txn.update(
          'expenses',
          values,
          where: 'id = ?',
          whereArgs: [original.id],
        );
        if (changed != 1) throw StateError('This expense no longer exists.');
      }
      await txn.update(
        'preferences',
        {'lastPaymentMethod': input.paymentMethod},
        where: 'id = ?',
        whereArgs: [1],
      );
      // Read inside the same transaction: any failure rolls back the whole save.
      return _read(txn);
    });
  }

  @override
  Future<AppData> delete(int id) async =>
      (await database.open()).transaction((txn) async {
        final changed = await txn.delete(
          'expenses',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (changed != 1) throw StateError('This expense no longer exists.');
        return _read(txn);
      });
  @override
  Future<AppData> setBudget(String amount) async {
    final cents = parseCents(amount);
    return (await database.open()).transaction((txn) async {
      await txn.update(
        'preferences',
        {'weeklyBudgetCents': cents},
        where: 'id = ?',
        whereArgs: [1],
      );
      return _read(txn);
    });
  }

  @override
  Future<AppData> dismissSampleNotice() async =>
      (await database.open()).transaction((txn) async {
        await txn.update(
          'preferences',
          {'sampleNoticeDismissed': 1},
          where: 'id = ?',
          whereArgs: [1],
        );
        return _read(txn);
      });
}
