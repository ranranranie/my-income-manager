import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../settings/amount_visibility.dart';
import '../data/income_database.dart';
import '../models/income_models.dart';

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
      const _SectionTitle('수입 관리'),
      const SizedBox(height: 8),
      Card(margin: EdgeInsets.zero, child: Column(children: [
        _Row(icon: Icons.business_outlined, title: '수입처 관리', subtitle: '유형별 수입처를 등록하고 관리합니다.', trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _SourceManagementPage()))),
        const Divider(height: 1),
        _Row(icon: Icons.account_balance_outlined, title: '계좌 관리', subtitle: '배당·이자 계좌를 등록하고 관리합니다.', trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AccountManagementPage()))),
      ])),
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
  const _Row({required this.icon, required this.title, required this.subtitle, this.trailing, this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override Widget build(BuildContext context) => InkWell(onTap: onTap, child: Padding(
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
  ));
}


class _SourceManagementPage extends StatefulWidget {
  const _SourceManagementPage();
  @override State<_SourceManagementPage> createState() => _SourceManagementPageState();
}
class _SourceManagementPageState extends State<_SourceManagementPage> {
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('수입처 관리')), body: FutureBuilder<List<IncomeSourceEntry>>(
    future: IncomeDatabase.instance.allSources(),
    builder: (context, snapshot) {
      final items = snapshot.data ?? const [];
      return ListView(padding: const EdgeInsets.all(18), children: [
        for (final group in ['company','dividend','interest','sideJob','appTech','other']) ...[
          _SectionTitle(_sourceGroupLabel(group)),
          const SizedBox(height: 6),
          Card(margin: const EdgeInsets.only(bottom: 16), child: Column(children: [
            for (final item in items.where((e) => e.groupKey == group))
              ListTile(title: Text(item.name), subtitle: Text(item.isActive ? '사용 중' : '비활성'), trailing: Switch(value: item.isActive, onChanged: (v) async { await IncomeDatabase.instance.setSourceActive(item.id, v); setState(() {}); }), onTap: () => _renameSource(context, item)),
            ListTile(leading: const Icon(Icons.add), title: const Text('새 수입처 등록'), onTap: () => _addSource(context, group)),
          ])),
        ],
      ]);
    },
  ));

  Future<void> _addSource(BuildContext context, String group) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: Text('${_sourceGroupLabel(group)} 등록'), content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: '이름')), actions: [TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('등록'))]));
    if (ok == true && controller.text.trim().isNotEmpty) {
      try { await IncomeDatabase.instance.addSource(_typeForGroup(group), controller.text); setState(() {}); }
      on DatabaseException catch (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이미 등록된 수입처입니다.'))); }
    }
  }
  Future<void> _renameSource(BuildContext context, IncomeSourceEntry item) async {
    final controller = TextEditingController(text:item.name);
    final ok = await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('수입처 이름 수정'),content:TextField(controller:controller,autofocus:true),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('저장'))]));
    if(ok==true && controller.text.trim().isNotEmpty){try{await IncomeDatabase.instance.renameSource(item,controller.text);setState((){});}on DatabaseException catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('이미 등록된 수입처입니다.')));}}
  }
}

class _AccountManagementPage extends StatefulWidget {
  const _AccountManagementPage();
  @override State<_AccountManagementPage> createState()=>_AccountManagementPageState();
}
class _AccountManagementPageState extends State<_AccountManagementPage>{
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('계좌 관리')),body:FutureBuilder<List<IncomeAccountEntry>>(future:IncomeDatabase.instance.accounts(includeInactive:true),builder:(context,snapshot){
    final items=snapshot.data??const[];
    return ListView(padding:const EdgeInsets.all(18),children:[
      Card(margin:EdgeInsets.zero,child:Column(children:[
        for(final item in items) ListTile(title:Text(item.name),subtitle:Text([if(item.institution?.isNotEmpty==true)item.institution!,item.isActive?'사용 중':'비활성'].join(' · ')),trailing:Switch(value:item.isActive,onChanged:(v)async{await IncomeDatabase.instance.setAccountActive(item.id,v);setState((){});}),onTap:()=>_edit(context,item)),
        ListTile(leading:const Icon(Icons.add),title:const Text('새 계좌 등록'),onTap:()=>_edit(context,null)),
      ]))
    ]);
  }));
  Future<void> _edit(BuildContext context,IncomeAccountEntry? item)async{
    final name=TextEditingController(text:item?.name??'');final institution=TextEditingController(text:item?.institution??'');
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:Text(item==null?'계좌 등록':'계좌 수정'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,autofocus:true,decoration:const InputDecoration(labelText:'계좌 이름')),const SizedBox(height:10),TextField(controller:institution,decoration:const InputDecoration(labelText:'금융기관 (선택)'))]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('취소')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('저장'))]));
    if(ok==true&&name.text.trim().isNotEmpty){try{if(item==null){await IncomeDatabase.instance.addAccount(name.text,institution.text);}else{await IncomeDatabase.instance.updateAccount(item,name.text,institution.text);}setState((){});}on DatabaseException catch(_){if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('이미 등록된 계좌입니다.')));}}
  }
}

String _sourceGroupLabel(String group)=>switch(group){'company'=>'급여·상여','dividend'=>'배당','interest'=>'이자','sideJob'=>'부업','appTech'=>'앱테크',_=>'기타'};
IncomeType _typeForGroup(String group)=>switch(group){'company'=>IncomeType.salary,'dividend'=>IncomeType.dividend,'interest'=>IncomeType.interest,'sideJob'=>IncomeType.sideJob,'appTech'=>IncomeType.appTech,_=>IncomeType.other};
