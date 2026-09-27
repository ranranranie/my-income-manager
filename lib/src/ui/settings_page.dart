import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../settings/amount_visibility.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.amountVisibility});
  final AmountVisibility amountVisibility;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
    children: [
      Text('설정', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 22),
      const _SectionTitle('표시 설정'),
      const SizedBox(height: 8),
      Card(margin: EdgeInsets.zero, child: ListenableBuilder(
        listenable: amountVisibility,
        builder: (context, _) => _Row(
          icon: Icons.visibility_outlined,
          title: '금액 표시',
          subtitle: '화면의 금액을 표시합니다.',
          trailing: Switch(value: amountVisibility.showAmounts, onChanged: amountVisibility.setShowAmounts),
        ),
      )),
      const SizedBox(height: 22),
      const _SectionTitle('데이터 관리'),
      const SizedBox(height: 8),
      const Card(margin: EdgeInsets.zero, child: _Row(
        icon: Icons.smartphone_outlined,
        title: '데이터 저장',
        subtitle: '수입 기록은 이 기기에 저장됩니다.',
      )),
      const SizedBox(height: 22),
      const _SectionTitle('앱 정보'),
      const SizedBox(height: 8),
      Card(margin: EdgeInsets.zero, child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) => _Row(
          icon: Icons.info_outline,
          title: 'My Income Manager',
          subtitle: snapshot.hasData ? '버전 ${snapshot.data!.version}' : '버전 정보를 불러오는 중…',
        ),
      )),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold));
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.subtitle, this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: Row(children: [
      Container(
        width: 38, height: 38, alignment: Alignment.center,
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .55), borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
      if (trailing != null) ...[const SizedBox(width: 8), trailing!],
    ]),
  );
}
