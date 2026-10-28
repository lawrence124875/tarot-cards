import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/home_page.dart' show privacyPolicyUrl;
import '../../app/services.dart';
import '../../app/theme.dart';
import '../../core/events/event_bus.dart';
import '../../core/monetization/premium_service.dart';
import '../../l10n/l10n.dart';
import '../widgets/adaptive_layout.dart';

/// 開啟訂閱頁。[source]：從哪裡進來（統計 paywall_view 用，見 [PaywallShown]）。
/// [note]：頁首的說明（例：今天的抽牌次數用完）。回傳離開時是否為訂閱戶。
Future<bool> openPaywall(BuildContext context, {required String source, String? note}) async {
  final s = AppServices.of(context);
  s.events.emit(PaywallShown(source: source));
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PaywallPage(note: note)));
  return s.isPremium;
}

/// 訂閱頁（HANDOFF H 第 6 點）：年訂（預設選取，標每月約多少；有試用優惠時寫明試用與之後的年費）、
/// 月訂；恢復購買；續訂說明（Google Play 訂閱政策要求清楚揭露）。價格一律用商店回傳的當地字串。
class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key, this.note});

  final String? note;

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  late final Services _s = AppServices.of(context);
  List<SubscriptionPlan>? _plans; // null＝讀取中
  PlanPeriod _selected = PlanPeriod.yearly;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final p = _s.premium.canPurchase ? await _s.premium.plans() : const <SubscriptionPlan>[];
    if (!mounted) return;
    setState(() {
      _plans = p;
      if (p.isNotEmpty && !p.any((x) => x.period == _selected)) _selected = p.first.period;
    });
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _buy() async {
    final plan = _plans?.firstWhere((p) => p.period == _selected);
    if (plan == null) return;
    setState(() => _busy = true);
    final r = await _s.premium.purchase(plan);
    if (!mounted) return;
    setState(() => _busy = false);
    final l = context.l10n;
    switch (r) {
      case PurchaseOutcome.success:
        if (plan.hasTrial) _s.events.emit(TrialStarted(period: plan.period.name));
        _s.events.emit(Subscribed(period: plan.period.name));
        _toast(l.premiumThanks);
        Navigator.of(context).pop();
      case PurchaseOutcome.failed:
        _toast(l.premiumPurchaseFailed);
      case PurchaseOutcome.cancelled:
        break;
    }
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final ok = await _s.premium.restore();
    if (!mounted) return;
    setState(() => _busy = false);
    final l = context.l10n;
    if (ok) {
      _s.events.emit(const Subscribed(period: 'restore'));
      _toast(l.premiumThanks);
      Navigator.of(context).pop();
    } else {
      _toast(l.premiumRestoreNone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ValueListenableBuilder<bool>(
          valueListenable: _s.premium.isPremium,
          builder: (context, premium, _) => ListView(
            padding: readablePadding(context, horizontal: 28, bottom: 24, maxWidth: 560),
            children: [
              if (widget.note case final note?) ...[
                Text(note, style: t.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 20),
              ],
              Text(l.premiumTitle, style: t.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(l.premiumSubtitle,
                  style: t.bodyMedium?.copyWith(color: TarotColors.textSub), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              for (final b in [l.premiumBenefitCourses, l.premiumBenefitSpreads, l.premiumBenefitNoAds, l.premiumBenefitJournal])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Icon(Icons.check, size: 18, color: TarotColors.earth),
                    const SizedBox(width: 12),
                    Expanded(child: Text(b, style: t.bodyLarge)),
                  ]),
                ),
              const SizedBox(height: 8),
              Text(l.premiumFreeNote, style: t.bodySmall?.copyWith(color: TarotColors.textSub)),
              const SizedBox(height: 24),
              if (premium) ...[
                Text(l.premiumActive, style: t.bodyLarge, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _manage, child: Text(l.premiumManage)),
              ] else
                ..._purchaseArea(t, l),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _purchaseArea(TextTheme t, AppLocalizations l) {
    final plans = _plans;
    if (!_s.premium.canPurchase) {
      return [Text(l.premiumUnavailable, textAlign: TextAlign.center, style: t.bodyMedium)];
    }
    if (plans == null) return [const Center(child: CircularProgressIndicator())];
    if (plans.isEmpty) {
      return [
        Text(l.premiumLoadFailed, textAlign: TextAlign.center, style: t.bodyMedium),
        IconButton(
          onPressed: () {
            setState(() => _plans = null);
            _load();
          },
          icon: const Icon(Icons.refresh),
        ),
      ];
    }
    final locale = Localizations.localeOf(context).toString();
    final selected = plans.where((p) => p.period == _selected).firstOrNull;
    return [
      for (final p in plans)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PlanTile(
            title: p.period == PlanPeriod.monthly ? l.planMonthly : l.planYearly,
            price: p.price,
            detail: [
              if (p.hasTrial && p.period == PlanPeriod.yearly) l.premiumTrial(p.trialDays!, p.price),
              if (p.perMonth(locale) case final m?) l.planPerMonth(m),
            ].join('\n'),
            selected: _selected == p.period,
            onTap: () => setState(() => _selected = p.period),
          ),
        ),
      if (selected?.hasTrial ?? false)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(l.premiumTrialNote,
              style: t.bodySmall?.copyWith(color: TarotColors.textSub), textAlign: TextAlign.center),
        ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: _busy ? null : _buy,
        child: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text((selected?.hasTrial ?? false) ? l.premiumStartTrial : l.premiumSubscribe),
      ),
      TextButton(onPressed: _busy ? null : _restore, child: Text(l.premiumRestore)),
      const SizedBox(height: 8),
      Text(_ios ? l.premiumTermsIos : l.premiumTerms,
          style: t.bodySmall?.copyWith(color: TarotColors.textSub), textAlign: TextAlign.center),
      // App Store 審查（3.1.2）要求訂閱頁有使用條款與隱私權政策連結；使用條款用 Apple 標準 EULA。
      if (_ios)
        Wrap(alignment: WrapAlignment.center, children: [
          TextButton(onPressed: () => _open(_appleEula), child: Text(l.termsOfUse)),
          TextButton(onPressed: () => _open(privacyPolicyUrl), child: Text(l.menuPrivacyPolicy)),
        ]),
    ];
  }

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;
  static const _appleEula = 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

  Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  Future<void> _manage() => _open(_ios
      ? 'https://apps.apple.com/account/subscriptions'
      : 'https://play.google.com/store/account/subscriptions?package=com.lclab.tarot');
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.title,
    required this.price,
    this.detail = '',
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String price;

  /// 方案下方的小字（試用說明、每月約多少）；空字串不顯示。
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? TarotColors.earth : TarotColors.textSub.withValues(alpha: 0.35),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 20, color: selected ? TarotColors.earth : TarotColors.textSub),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.titleMedium),
                if (detail.isNotEmpty) Text(detail, style: t.bodySmall?.copyWith(color: TarotColors.textSub)),
              ]),
            ),
            const SizedBox(width: 8),
            Text(price, style: t.titleMedium),
          ]),
        ),
      ),
    );
  }
}
