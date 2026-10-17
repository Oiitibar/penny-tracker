import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:student_penny_tracker/app.dart';
import 'package:student_penny_tracker/core/models.dart';
import 'package:student_penny_tracker/core/strings.dart';
import 'package:student_penny_tracker/data/database.dart';
import 'package:student_penny_tracker/data/repository.dart';
import 'package:student_penny_tracker/state/providers.dart';

class ControlledRepository implements ExpenseRepository {
  ControlledRepository(this.delegate, this.cache) : ioZone = Zone.current;
  final ExpenseRepository delegate;
  final Zone ioZone;
  AppData cache;
  bool fail = false;
  Completer<void>? gate;
  int saveCalls = 0;
  Future<void>? pending;
  Future<AppData> _execute(Future<AppData> Function() operation) {
    // Native I/O runs on the real clock. Return errors as data across zones,
    // then rethrow in the widget's zone so the form can handle them normally.
    final result = ioZone.run<Future<(AppData?, Object?, StackTrace?)>>(
      () async {
        try {
          cache = await operation();
          return (cache, null, null);
        } catch (error, stack) {
          return (null, error, stack);
        }
      },
    );
    pending = result.then((_) {});
    return result.then((r) {
      if (r.$2 != null) Error.throwWithStackTrace(r.$2!, r.$3!);
      return r.$1!;
    });
  }

  @override
  Future<AppData> load() async => cache;
  @override
  Future<AppData> save(ExpenseInput input, {Expense? original}) {
    saveCalls++;
    return _execute(() async {
      if (gate != null) await gate!.future;
      if (fail) throw StateError('Simulated storage failure');
      return delegate.save(input, original: original);
    });
  }

  @override
  Future<AppData> delete(int id) => _execute(() => delegate.delete(id));
  @override
  Future<AppData> setBudget(String amount) =>
      _execute(() => delegate.setBudget(amount));
  @override
  Future<AppData> dismissSampleNotice() =>
      _execute(delegate.dismissSampleNotice);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late AppDatabase database;
  late ControlledRepository repository;
  late DateTime now;
  const capture = Key('app-capture');
  setUp(() async {
    now = DateTime(2026, 10, 15, 16, 30);
    database = AppDatabase(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
      clock: () => now,
    );
    final delegate = SqliteExpenseRepository(database, () => now);
    repository = ControlledRepository(delegate, await delegate.load());
  });
  tearDown(() => database.close());
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      try {
        await repository.pending;
      } catch (_) {
        /* UI asserts failure feedback. */
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> launch(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(scale),
          ),
          child: const RepaintBoundary(key: capture, child: PennyTrackerApp()),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tab(WidgetTester tester, int index) async {
    await tester.tap(find.byKey(Key('nav-$index')));
    await settle(tester);
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.byKey(const Key('save-expense'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settle(tester);
  }

  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
  }

  testWidgets(
    'navigation preserves draft; save updates budget and resets form',
    (tester) async {
      await launch(tester);
      expect(find.text(r'$454.35'), findsOneWidget);
      await tab(tester, 1);
      await tester.enterText(find.byKey(const Key('expense-amount')), '10.00');
      await tester.enterText(
        find.byKey(const Key('expense-name')),
        'Campus lunch',
      );
      await tab(tester, 0);
      await tab(tester, 1);
      expect(find.text('10.00'), findsOneWidget);
      await save(tester);
      expect(find.text(S.saved), findsOneWidget);
      expect(find.text(r'$444.35'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Campus lunch'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Campus lunch'), findsOneWidget);
      await tab(tester, 1);
      expect(find.text('10.00'), findsNothing);
      expect((await repository.load()).expenses.length, 5);
      await closeApp(tester);
    },
  );
  testWidgets('invalid amount is inline and does not save', (tester) async {
    await launch(tester);
    await tab(tester, 1);
    await tester.enterText(find.byKey(const Key('expense-amount')), '2.345');
    await save(tester);
    expect(find.text('Use no more than two decimal places.'), findsOneWidget);
    expect(repository.saveCalls, 0);
    expect(find.text('2.345'), findsOneWidget);
    await closeApp(tester);
  });
  testWidgets('Other reveals custom field, saves category and Card details', (
    tester,
  ) async {
    await launch(tester);
    await tab(tester, 1);
    await tester.enterText(find.byKey(const Key('expense-amount')), '3.50');
    await tester.enterText(
      find.byKey(const Key('expense-name')),
      'Library prints',
    );
    await tester.tap(find.byKey(const Key('category-8')));
    await settle(tester);
    expect(find.byKey(const Key('custom-category')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('custom-category')));
    await tester.enterText(
      find.byKey(const Key('custom-category')),
      'Printing',
    );
    await tester.ensureVisible(find.byKey(const Key('payment-card')));
    await tester.tap(find.byKey(const Key('payment-card')));
    await save(tester);
    final d = await repository.load();
    final e = d.expenses.firstWhere((e) => e.name == 'Library prints');
    expect(d.categoryFor(e).name, 'Printing');
    expect(e.paymentMethod, 'card');
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('expense-${e.id}')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(ValueKey('expense-${e.id}')));
    await settle(tester);
    expect(find.text('Printing'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
    expect(find.text(S.details), findsOneWidget);
    await closeApp(tester);
  });
  testWidgets('failed write retains input and never reports success', (
    tester,
  ) async {
    repository.fail = true;
    await launch(tester);
    await tab(tester, 1);
    await tester.enterText(find.byKey(const Key('expense-amount')), '12.34');
    await tester.enterText(
      find.byKey(const Key('expense-name')),
      'Keep my draft',
    );
    await save(tester);
    expect(find.text(S.saveFailed), findsOneWidget);
    expect(find.text(S.saved), findsNothing);
    expect(find.text('12.34'), findsOneWidget);
    expect(find.text('Keep my draft'), findsOneWidget);
    expect((await repository.load()).expenses.length, 4);
    repository.fail = false;
    await save(tester);
    expect((await repository.load()).expenses.length, 5);
    await closeApp(tester);
  });
  testWidgets('repeated Save taps create one transaction', (tester) async {
    repository.gate = Completer<void>();
    await launch(tester);
    await tab(tester, 1);
    await tester.enterText(find.byKey(const Key('expense-amount')), '10.00');
    final button = find.byKey(const Key('save-expense'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.tap(button);
    await tester.pump();
    expect(repository.saveCalls, 1);
    repository.gate!.complete();
    await settle(tester);
    expect((await repository.load()).expenses.length, 5);
    await closeApp(tester);
  });
  testWidgets('filters update total and transaction subset together', (
    tester,
  ) async {
    await launch(tester);
    await tab(tester, 2);
    expect(tester.getSize(find.byKey(const ValueKey('segment-3'))).height, 14);
    expect(
      tester.getSize(find.byKey(const ValueKey('segment-3'))).width,
      greaterThan(100),
    );
    expect(find.text(r'$120.65'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-today')));
    await settle(tester);
    expect(find.text(r'$4.50'), findsWidgets);
    expect(find.text('City Transit'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Campus Coffee'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Campus Coffee'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-month')));
    await settle(tester);
    expect(find.text(r'$120.65'), findsOneWidget);
    await closeApp(tester);
  });
  testWidgets(
    'editing and delete cancellation/confirmation refresh all views',
    (tester) async {
      await launch(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('expense-1')),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('expense-1')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('edit-transaction')));
      await settle(tester);
      await tester.enterText(find.byKey(const Key('expense-amount')), '14.50');
      await save(tester);
      expect(find.text(S.updated), findsOneWidget);
      expect(
        (await repository.load()).expenses
            .firstWhere((e) => e.id == 1)
            .amountCents,
        1450,
      );
      await tester.tap(find.byKey(const ValueKey('expense-1')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('delete-transaction')));
      await settle(tester);
      await tester.tap(find.text(S.cancel));
      await settle(tester);
      expect((await repository.load()).expenses.length, 4);
      await tester.tap(find.byKey(const Key('delete-transaction')));
      await settle(tester);
      await tester.tap(find.byKey(const Key('confirm-delete')));
      await settle(tester);
      expect((await repository.load()).expenses.length, 3);
      expect(find.text(S.deleted), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(r'$458.85'),
        -180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(r'$458.85'), findsOneWidget);
      await closeApp(tester);
    },
  );
  testWidgets('budget editor rejects zero then immediately refreshes Home', (
    tester,
  ) async {
    await launch(tester);
    await tester.tap(find.text(S.editBudget));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('budget-input')), '0');
    await tester.tap(find.text(S.saveChanges));
    await settle(tester);
    expect(find.text(r'Enter an amount greater than $0.00.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('budget-input')), '600');
    await tester.tap(find.text(S.saveChanges));
    await settle(tester);
    expect(find.text(r'$479.35'), findsOneWidget);
    await closeApp(tester);
  });
  testWidgets('resume recomputes current week from the injected clock', (
    tester,
  ) async {
    await launch(tester);
    now = DateTime(2026, 10, 19, 0, 1);
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await settle(tester);
    expect(find.text(r'$575.00'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Campus Coffee'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Campus Coffee'), findsOneWidget);
    await closeApp(tester);
  });
  testWidgets('foreground midnight refresh starts the next weekly allowance', (
    tester,
  ) async {
    now = DateTime(2026, 10, 18, 23, 59);
    await launch(tester);
    expect(find.text(r'$454.35'), findsOneWidget);
    now = DateTime(2026, 10, 19, 0, 1);
    await tester.pump(const Duration(minutes: 2));
    await settle(tester);
    expect(find.text(r'$575.00'), findsOneWidget);
    await closeApp(tester);
  });
  testWidgets('small phone, 200% text and keyboard leave form reachable', (
    tester,
  ) async {
    await launch(tester, size: const Size(320, 640), scale: 2);
    expect(tester.takeException(), isNull);
    await tab(tester, 1);
    await tester.enterText(find.byKey(const Key('expense-amount')), '5.00');
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await settle(tester);
    await tester.ensureVisible(find.byKey(const Key('save-expense')));
    expect(find.byKey(const Key('save-expense')).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await closeApp(tester);
  });
  testWidgets('capture actual Flutter screens at 390 x 844', (tester) async {
    for (final font in ['PlusJakartaSans', 'NunitoSans']) {
      final loader = FontLoader(
        font == 'PlusJakartaSans' ? 'Plus Jakarta Sans' : 'Nunito Sans',
      );
      loader.addFont(rootBundle.load('assets/fonts/$font.ttf'));
      await loader.load();
    }
    final emojiFile = File('/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf');
    if (emojiFile.existsSync()) {
      final emoji = FontLoader('Noto Color Emoji');
      emoji.addFont(
        Future.value(ByteData.sublistView(emojiFile.readAsBytesSync())),
      );
      await emoji.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await launch(tester);
    for (var i = 0; i < 3; i++) {
      await tab(tester, i);
      await settle(tester);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(capture),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
        final dir = Directory('artifacts/screenshots')
          ..createSync(recursive: true);
        await File(
          '${dir.path}/${['home', 'add', 'insights'][i]}.png',
        ).writeAsBytes(bytes.buffer.asUint8List());
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    }
    await closeApp(tester);
  });
}
