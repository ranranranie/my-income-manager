import 'package:flutter/material.dart';
import 'settings/amount_visibility.dart';
import 'ui/history_page.dart';
import 'ui/home_page.dart';
import 'ui/income_editor.dart';
import 'ui/report_page.dart';
import 'ui/settings_page.dart';

class IncomeApp extends StatefulWidget {
  const IncomeApp({super.key});
  @override State<IncomeApp> createState() => _IncomeAppState();
}

class _IncomeAppState extends State<IncomeApp> {
  int index = 0, revision = 0;
  final amountVisibility = AmountVisibility();

  @override void initState() { super.initState(); amountVisibility.load(); }
  @override void dispose() { amountVisibility.dispose(); super.dispose(); }
  void refresh() => setState(() => revision++);

  @override Widget build(BuildContext context) => ListenableBuilder(
    listenable: amountVisibility,
    builder: (context, _) {
      final showAmounts = amountVisibility.showAmounts;
      final pages = [
        HomePage(revision: revision, onOpenHistory: () => setState(() => index = 1), showAmounts: showAmounts),
        HistoryPage(revision: revision, onChanged: refresh, showAmounts: showAmounts),
        ReportPage(revision: revision, showAmounts: showAmounts),
        SettingsPage(amountVisibility: amountVisibility),
      ];
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'My Income Manager',
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff68856d), surface: const Color(0xfffffbf2)), scaffoldBackgroundColor: const Color(0xfffffbf2), useMaterial3: true),
        home: Scaffold(
          body: SafeArea(child: pages[index]),
          bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v), destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: '내역'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: '리포트'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), label: '설정'),
          ]),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: FloatingActionButton(tooltip: '수입 기록', onPressed: () async {
            final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const IncomeEditor()));
            if (saved == true) refresh();
          }, child: const Icon(Icons.add)),
        ),
      );
    },
  );
}
