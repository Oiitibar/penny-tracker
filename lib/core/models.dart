/// Source records contain cents and calendar strings, never floating money.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.isCustom,
    required this.iconKey,
    required this.colorHex,
  });
  final int id;
  final String name, normalizedName, iconKey, colorHex;
  final bool isCustom;
  factory Category.fromMap(Map<String, Object?> m) => Category(
    id: m['id'] as int,
    name: m['name'] as String,
    normalizedName: m['normalizedName'] as String,
    isCustom: m['isCustom'] == 1,
    iconKey: m['iconKey'] as String,
    colorHex: m['colorHex'] as String,
  );
}

class Expense {
  const Expense({
    required this.id,
    required this.name,
    required this.amountCents,
    required this.categoryId,
    required this.expenseDate,
    required this.expenseTime,
    required this.paymentMethod,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  final int id, amountCents, categoryId;
  final String name,
      expenseDate,
      expenseTime,
      paymentMethod,
      createdAtUtc,
      updatedAtUtc;
  factory Expense.fromMap(Map<String, Object?> m) => Expense(
    id: m['id'] as int,
    name: m['name'] as String,
    amountCents: m['amountCents'] as int,
    categoryId: m['categoryId'] as int,
    expenseDate: m['expenseDate'] as String,
    expenseTime: m['expenseTime'] as String,
    paymentMethod: m['paymentMethod'] as String,
    createdAtUtc: m['createdAtUtc'] as String,
    updatedAtUtc: m['updatedAtUtc'] as String,
  );
}

class Preferences {
  const Preferences({
    this.weeklyBudgetCents = 57500,
    this.currencyCode = 'USD',
    this.displayName = 'Crystal',
    this.lastPaymentMethod = 'cash',
    this.sampleNoticeDismissed = false,
  });
  final int weeklyBudgetCents;
  final String currencyCode, displayName, lastPaymentMethod;
  final bool sampleNoticeDismissed;
  factory Preferences.fromMap(Map<String, Object?> m) => Preferences(
    weeklyBudgetCents: m['weeklyBudgetCents'] as int,
    currencyCode: m['currencyCode'] as String,
    displayName: m['displayName'] as String,
    lastPaymentMethod: m['lastPaymentMethod'] as String,
    sampleNoticeDismissed: m['sampleNoticeDismissed'] == 1,
  );
}

class AppData {
  const AppData({
    required this.expenses,
    required this.categories,
    required this.preferences,
  });
  final List<Expense> expenses;
  final List<Category> categories;
  final Preferences preferences;
  Category categoryFor(Expense expense) =>
      categories.firstWhere((c) => c.id == expense.categoryId);
}

class ExpenseInput {
  const ExpenseInput({
    required this.amount,
    required this.name,
    required this.categoryId,
    required this.date,
    required this.paymentMethod,
    this.customCategory,
  });
  final String amount, name, date, paymentMethod;
  final int categoryId;
  final String? customCategory;
}
