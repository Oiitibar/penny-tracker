import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/strings.dart';
import 'core/theme.dart';
import 'features/dashboard.dart';
import 'features/expense_form.dart';
import 'features/insights.dart';
import 'shared/widgets.dart';
import 'state/providers.dart';

class PennyTrackerApp extends StatelessWidget {
  const PennyTrackerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: S.appName,
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: const MainNavigation(),
  );
}

class MainNavigation extends ConsumerStatefulWidget {
  const MainNavigation({super.key});
  @override
  ConsumerState<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends ConsumerState<MainNavigation>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnight();
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    final now = ref.read(clockProvider)();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      next.difference(now) + const Duration(milliseconds: 100),
      () {
        _refresh();
        _scheduleMidnight();
      },
    );
  }

  Future<void> _refresh() async {
    try {
      await ref.read(appStoreProvider.notifier).refresh();
    } catch (_) {
      if (mounted) feedback(context, S.loadHelp);
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _scheduleMidnight();
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStoreProvider);
    final tab = ref.watch(tabProvider);
    final now = ref.read(clockProvider)();
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) ref.read(tabProvider.notifier).state = 0;
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: state.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: C.success),
            ),
            error: (_, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.savings_outlined,
                      size: 48,
                      color: C.success,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      S.loadFailed,
                      style: heading(20),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      S.loadHelp,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: C.secondary),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => ref.invalidate(appStoreProvider),
                      child: const Text(S.retry),
                    ),
                  ],
                ),
              ),
            ),
            data: (data) => IndexedStack(
              index: tab,
              children: [
                DashboardScreen(data: data, now: now),
                AddExpenseScreen(
                  data: data,
                  now: now,
                  onSaved: () {
                    ref.read(tabProvider.notifier).state = 0;
                    feedback(context, S.saved);
                  },
                ),
                InsightsScreen(data: data, now: now),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: C.border)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: _NavItem(
                        index: i,
                        selected: tab == i,
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          ref.read(tabProvider.notifier).state = i;
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.index,
    required this.selected,
    required this.onTap,
  });
  final int index;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final label = [S.home, S.add, S.insights][index];
    final icon = [
      selected ? Icons.home_rounded : Icons.home_outlined,
      Icons.add_circle_outline_rounded,
      selected ? Icons.bar_chart_rounded : Icons.bar_chart_outlined,
    ][index];
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: InkWell(
        key: Key('nav-$index'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                padding: const EdgeInsets.symmetric(vertical: 5),
                decoration: BoxDecoration(
                  color: selected ? C.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: selected ? const Color(0xFF087260) : C.secondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? const Color(0xFF087260) : C.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
