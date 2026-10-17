import 'strings.dart';
import 'package:intl/intl.dart';
import 'models.dart';

typedef AppClock = DateTime Function();
const maxAmountCents = 99999999;
const currencyCode = 'USD';
final _currency = NumberFormat.currency(
  locale: 'en_US',
  symbol: r'$',
  decimalDigits: 2,
);
String money(int cents) => _currency.format(cents / 100);
String amountText(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

int parseCents(String value) {
  final text = value.trim();
  if (RegExp(r'^\d+\.\d{3,}$').hasMatch(text)) {
    throw const FormatException(S.precisionError);
  }
  if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(text)) {
    throw const FormatException(S.amountError);
  }
  // Length check also prevents integer overflow on oversized pasted input.
  final parts = text.split('.');
  final whole = parts.first.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (whole.length > 6) {
    throw const FormatException(S.rangeError);
  }
  final cents =
      int.parse(whole) * 100 +
      int.parse(parts.length == 2 ? parts[1].padRight(2, '0') : '0');
  if (cents == 0) {
    throw const FormatException(S.positiveError);
  }
  if (cents > maxAmountCents) {
    throw const FormatException(S.rangeError);
  }
  return cents;
}

String cleanCategoryName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');
String normalizedCategoryName(String value) =>
    cleanCategoryName(value).toLowerCase();
String? validateCategory(String value) {
  final clean = cleanCategoryName(value);
  return clean.isEmpty || clean.runes.length > 24 ? S.categoryError : null;
}

DateTime calendarDay(DateTime d) => DateTime(d.year, d.month, d.day);
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String timeKey(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
DateTime parseDate(String key) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) {
    throw const FormatException(S.invalidDate);
  }
  final p = key.split('-').map(int.parse).toList();
  final d = DateTime(p[0], p[1], p[2]);
  if (p[0] < 1900 || dateKey(d) != key) {
    throw const FormatException(S.invalidDate);
  }
  return d;
}

String? validateDate(String value, DateTime now) {
  try {
    final day = parseDate(value);
    if (day.isAfter(calendarDay(now))) {
      return S.futureDate;
    }
  } on FormatException catch (e) {
    return e.message;
  }
  return null;
}

enum Period { today, week, month }

extension PeriodLabel on Period {
  String get label => switch (this) {
    Period.today => 'Today',
    Period.week => 'Week',
    Period.month => 'Month',
  };
  String get phrase => switch (this) {
    Period.today => 'today',
    Period.week => 'this week',
    Period.month => 'this month',
  };
}

class DateRange {
  const DateRange(this.start, this.end);
  final DateTime start, end;
  bool contains(String date) =>
      date.compareTo(dateKey(start)) >= 0 && date.compareTo(dateKey(end)) < 0;
  String get label {
    final last = DateTime(end.year, end.month, end.day - 1);
    if (dateKey(start) == dateKey(last)) {
      return DateFormat('EEEE, MMM d, y').format(start);
    }
    if (start.year != last.year) {
      return '${DateFormat('MMM d, y').format(start)} – ${DateFormat('MMM d, y').format(last)}';
    }
    return '${DateFormat('MMM d').format(start)} – ${DateFormat(start.month == last.month ? 'd, y' : 'MMM d, y').format(last)}';
  }
}

DateRange dateRange(Period period, DateTime now) {
  final d = calendarDay(now);
  return switch (period) {
    Period.today => DateRange(d, DateTime(d.year, d.month, d.day + 1)),
    Period.week => DateRange(
      DateTime(d.year, d.month, d.day - d.weekday + 1),
      DateTime(d.year, d.month, d.day - d.weekday + 8),
    ),
    Period.month => DateRange(
      DateTime(d.year, d.month),
      DateTime(d.year, d.month + 1),
    ),
  };
}

int compareExpenses(Expense a, Expense b) =>
    b.expenseDate.compareTo(a.expenseDate) != 0
    ? b.expenseDate.compareTo(a.expenseDate)
    : b.expenseTime.compareTo(a.expenseTime) != 0
    ? b.expenseTime.compareTo(a.expenseTime)
    : b.createdAtUtc.compareTo(a.createdAtUtc) != 0
    ? b.createdAtUtc.compareTo(a.createdAtUtc)
    : b.id.compareTo(a.id);

class CategoryTotal {
  const CategoryTotal(this.category, this.cents, this.share, this.percent);
  final Category category;
  final int cents, percent;
  final double share;
}

class SpendingReport {
  SpendingReport(AppData data, Period period, DateTime now) {
    range = dateRange(period, now);
    expenses =
        data.expenses.where((e) => range.contains(e.expenseDate)).toList()
          ..sort(compareExpenses);
    totalCents = expenses.fold(0, (sum, e) => sum + e.amountCents);
    final totals = <int, int>{};
    for (final e in expenses) {
      totals.update(
        e.categoryId,
        (v) => v + e.amountCents,
        ifAbsent: () => e.amountCents,
      );
    }
    final ordered =
        data.categories.where((c) => totals.containsKey(c.id)).toList()
          ..sort((a, b) {
            final amountOrder = totals[b.id]!.compareTo(totals[a.id]!);
            return amountOrder != 0
                ? amountOrder
                : a.normalizedName.compareTo(b.normalizedName);
          });
    // Largest remainders allocate whole percentages to exactly 100, stably.
    final percents = ordered
        .map((c) => totals[c.id]! * 100 ~/ totalCents)
        .toList();
    final remainderOrder = List.generate(ordered.length, (i) => i)
      ..sort((a, b) {
        final order = (totals[ordered[b].id]! * 100 % totalCents).compareTo(
          totals[ordered[a].id]! * 100 % totalCents,
        );
        return order == 0 ? a.compareTo(b) : order;
      });
    final left = totalCents == 0 ? 0 : 100 - percents.fold(0, (a, b) => a + b);
    for (var i = 0; i < left; i++) {
      percents[remainderOrder[i]]++;
    }
    categories = [
      for (var i = 0; i < ordered.length; i++)
        CategoryTotal(
          ordered[i],
          totals[ordered[i].id]!,
          totals[ordered[i].id]! / totalCents,
          percents[i],
        ),
    ];
  }
  late final DateRange range;
  late final List<Expense> expenses;
  late final int totalCents;
  late final List<CategoryTotal> categories;
}

class BudgetSummary {
  BudgetSummary(AppData data, DateTime now)
    : budgetCents = data.preferences.weeklyBudgetCents,
      spentCents = SpendingReport(data, Period.week, now).totalCents,
      daysLeft = 8 - now.weekday;
  final int budgetCents, spentCents, daysLeft;
  int get remainingCents => budgetCents - spentCents;
  double get remainingRatio => (remainingCents / budgetCents).clamp(0.0, 1.0);
  int get remainingPercent => (remainingRatio * 100).round();
  String get status => remainingCents < 0
      ? S.over
      : remainingCents == 0
      ? S.budgetUsed
      : remainingRatio < .25
      ? S.gettingLow
      : S.onTrack;
  String get guidance => remainingCents < 0
      ? S.overGuidance(money(-remainingCents))
      : S.balanceGuidance(money(remainingCents), daysLeft);
}
