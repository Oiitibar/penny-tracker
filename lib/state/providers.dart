import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/finance.dart';
import '../core/models.dart';
import '../data/database.dart';
import '../data/repository.dart';

final clockProvider = Provider<AppClock>((ref) => DateTime.now);
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase(clock: ref.watch(clockProvider));
  ref.onDispose(database.close);
  return database;
});
final repositoryProvider = Provider<ExpenseRepository>(
  (ref) => SqliteExpenseRepository(
    ref.watch(databaseProvider),
    ref.watch(clockProvider),
  ),
);
final appStoreProvider = AsyncNotifierProvider<AppStore, AppData>(AppStore.new);
final tabProvider = StateProvider<int>((ref) => 0);
final periodProvider = StateProvider<Period>((ref) => Period.week);

class AppStore extends AsyncNotifier<AppData> {
  int _revision = 0;
  @override
  Future<AppData> build() => ref.watch(repositoryProvider).load();

  Future<void> refresh() async {
    final revision = _revision;
    final data = await ref.read(repositoryProvider).load();
    if (revision == _revision) state = AsyncData(data);
  }

  Future<void> _write(
    Future<AppData> Function(ExpenseRepository repo) operation,
  ) async {
    _revision++;
    final data = await operation(ref.read(repositoryProvider));
    _revision++;
    state = AsyncData(data);
  }

  Future<void> save(ExpenseInput input, {Expense? original}) =>
      _write((repo) => repo.save(input, original: original));
  Future<void> delete(int id) => _write((repo) => repo.delete(id));
  Future<void> setBudget(String amount) =>
      _write((repo) => repo.setBudget(amount));
  Future<void> dismissSampleNotice() =>
      _write((repo) => repo.dismissSampleNotice());
}
