import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../core/finance.dart';

/// Schema changes belong in ordered migrations; seeds run only in onCreate.
class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? path, required this.clock})
    : _factory = factory ?? databaseFactory,
      _path = path;
  static const schemaVersion = 1;
  final DatabaseFactory _factory;
  final String? _path;
  final AppClock clock;
  Database? _database;
  Future<Database>? _opening;

  Future<Database> open() async {
    try {
      return await (_opening ??= _open());
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _open() async {
    final path =
        _path ??
        p.join(await _factory.getDatabasesPath(), 'student_penny_tracker.db');
    final db = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          normalizedName TEXT NOT NULL UNIQUE,
          isCustom INTEGER NOT NULL CHECK(isCustom IN (0, 1)),
          iconKey TEXT NOT NULL,
          colorHex TEXT NOT NULL
        )''');
          await db.execute('''CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL CHECK(length(trim(name)) BETWEEN 1 AND 60),
          amountCents INTEGER NOT NULL CHECK(amountCents BETWEEN 1 AND 99999999),
          categoryId INTEGER NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
          expenseDate TEXT NOT NULL,
          expenseTime TEXT NOT NULL,
          paymentMethod TEXT NOT NULL CHECK(paymentMethod IN ('cash', 'card')),
          createdAtUtc TEXT NOT NULL,
          updatedAtUtc TEXT NOT NULL
        )''');
          await db.execute(
            'CREATE INDEX expenses_date ON expenses(expenseDate DESC, expenseTime DESC, createdAtUtc DESC, id DESC)',
          );
          await db.execute(
            'CREATE INDEX expenses_category ON expenses(categoryId)',
          );
          await db.execute('''CREATE TABLE preferences (
          id INTEGER PRIMARY KEY CHECK(id = 1),
          weeklyBudgetCents INTEGER NOT NULL CHECK(weeklyBudgetCents BETWEEN 1 AND 99999999),
          currencyCode TEXT NOT NULL DEFAULT 'USD',
          displayName TEXT NOT NULL DEFAULT 'Crystal',
          lastPaymentMethod TEXT NOT NULL DEFAULT 'cash' CHECK(lastPaymentMethod IN ('cash', 'card')),
          sampleNoticeDismissed INTEGER NOT NULL DEFAULT 0 CHECK(sampleNoticeDismissed IN (0, 1)),
          seedInitialized INTEGER NOT NULL DEFAULT 1
        )''');
          await db.insert('preferences', {'id': 1, 'weeklyBudgetCents': 57500});
          for (var i = 0; i < defaultCategories.length; i++) {
            final c = defaultCategories[i];
            await db.insert('categories', {
              'id': i + 1,
              'name': c.$1,
              'normalizedName': c.$1.toLowerCase(),
              'isCustom': 0,
              'iconKey': c.$2,
              'colorHex': c.$3,
            });
          }
          final now = clock();
          final samples = [
            ('Campus Coffee', 450, 1, 0, 'cash'),
            ('City Transit', 275, 2, 1, 'card'),
            ('Student Market', 2840, 1, 2, 'cash'),
            ('University Bookstore', 8500, 3, 3, 'card'),
          ];
          for (final (name, amount, category, daysAgo, payment) in samples) {
            final date = DateTime(now.year, now.month, now.day - daysAgo);
            // Today's seed never appears at a time later than the initial launch.
            final candidate = DateTime(
              date.year,
              date.month,
              date.day,
              daysAgo == 0 ? 9 : 14,
              15,
            );
            final recorded = candidate.isAfter(now) ? now : candidate;
            final stamp = now.toUtc().toIso8601String();
            await db.insert('expenses', {
              'name': name,
              'amountCents': amount,
              'categoryId': category,
              'expenseDate': dateKey(date),
              'expenseTime': timeKey(recorded),
              'paymentMethod': payment,
              'createdAtUtc': stamp,
              'updatedAtUtc': stamp,
            });
          }
        },
        // Every future version must supply an explicit migration, never reset data.
        onUpgrade: (db, oldVersion, newVersion) async {
          throw StateError(
            'A database migration from $oldVersion to $newVersion is required.',
          );
        },
        onDowngrade: (db, oldVersion, newVersion) async =>
            throw StateError('This database was created by a newer app.'),
      ),
    );
    _database = db;
    return db;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _opening = null;
  }
}

const defaultCategories = [
  ('Food', 'food', '#4ECDC4'),
  ('Transport', 'transport', '#FFA568'),
  ('Study', 'study', '#8F9FE0'),
  ('Shop', 'shop', '#DA92B0'),
  ('Health', 'health', '#68AB8D'),
  ('Bills', 'bills', '#B69A69'),
  ('Fun', 'fun', '#B093D2'),
  ('Other', 'other', '#1F3C88'),
];
const customColors = ['#4B8B9B', '#B47E55', '#8472AD', '#548B6E', '#AE6B84'];
