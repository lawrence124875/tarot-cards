import 'package:flutter/material.dart';

import '../../app/services.dart';
import '../../shared/premium/paywall_page.dart';

import '../../core/soundscape/sound_bed.dart';
import '../../core/tarot/tarot_card.dart';
import '../../core/soundscape/session_renderer.dart';
import 'breath_page.dart';
import '../../l10n/l10n.dart';

/// 開始前的設定：時長 1／2／3／5 分鐘或自訂 5–60 分鐘（0.2.0+48，會員）、換氣鈴聲、雙耳節拍（皆預設關閉；雙耳節拍可選 128Hz 或 216Hz）。
/// 文案只描述做法，不寫任何療效（Google Play 健康宣稱政策，HANDOFF §14.2）。
/// 選擇只在這次開啟 App 期間記住（不另存檔）。
Future<void> showBreathSetup(BuildContext context, int cardId) async {
  final spec = await showModalBottomSheet<SessionSpec>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SetupSheet(cardId: cardId),
  );
  if (spec == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => BreathPage(cardId: cardId, spec: spec),
  ));
}

class _SetupSheet extends StatefulWidget {
  const _SetupSheet({required this.cardId});

  final int cardId;

  @override
  State<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<_SetupSheet> {
  static const _choices = [1, 2, 3, 5];
  static int _lastMinutes = 3;

  /// 自訂時長：5–60 分鐘，每格 5 分鐘（長時間靜坐用）。
  static const _customMin = 5, _customMax = 60, _customStep = 5;
  static int _lastCustom = 20;
  bool _custom = !_choices.contains(_lastMinutes);
  int _customMinutes = _lastCustom;
  static bool _lastBells = false; // 預設關閉（2026-10-02 使用者決定）

  int _minutes = _lastMinutes;
  bool _bells = _lastBells;
  static bool _lastBinaural = false;
  bool _binaural = _lastBinaural;
  static BinauralCarrier _lastCarrier = BinauralCarrier.c128;
  BinauralCarrier _carrier = _lastCarrier;

  // 免費版（§23）：只有 1／2 分鐘、沒有雙耳節拍；其餘點了開訂閱頁
  late final Services _s = AppServices.of(context);
  bool _locked(int minutes) => !_s.isPremium && !_s.limits.freeBreathMinutes.contains(minutes);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _s.isPremium) return;
      setState(() {
        if (_locked(_minutes)) {
          _minutes = 2;
          _custom = false;
        }
        _binaural = false;
      });
    });
  }

  void _pick(int m) {
    _custom = false;
    _minutes = m;
  }

  void _pickCustom() {
    _custom = true;
    _minutes = _customMinutes;
  }

  /// 點了會員功能：開訂閱頁，訂閱成功就套用。
  Future<void> _unlock(VoidCallback apply) async {
    if (await openPaywall(context, source: 'breath') && mounted) setState(apply);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l10n;
    final card = TarotCard.byId(widget.cardId);
    final beds = bedsFor(card.element);
    final sounds = l.breathSoundElement(
        l.elementLabel(card.element), l.soundscape(beds.upper), l.soundscape(beds.lower));

    // 內容可捲動、底部讓出系統導覽列，「開始」不會被擋住（0.1.0+12）
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(28, 24, 28, 20 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.breathSetupTitle(l.cardName(widget.cardId)), style: t.titleMedium),
            const SizedBox(height: 8),
            Text(sounds, style: t.bodyMedium),
            const SizedBox(height: 4),
            Text(l.breathSetupNote, style: t.bodySmall),
            const SizedBox(height: 16),
            Text(l.breathDuration, style: t.bodyMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                for (final m in _choices)
                  ChoiceChip(
                    avatar: _locked(m) ? const Icon(Icons.lock_outline, size: 16) : null,
                    label: Text(l.minutes(m)),
                    selected: !_custom && _minutes == m,
                    onSelected: (_) => _locked(m) ? _unlock(() => _pick(m)) : setState(() => _pick(m)),
                  ),
                ChoiceChip(
                  avatar: _s.isPremium ? null : const Icon(Icons.lock_outline, size: 16),
                  label: Text(l.breathCustom),
                  selected: _custom,
                  onSelected: (_) => _s.isPremium ? setState(_pickCustom) : _unlock(_pickCustom),
                ),
              ],
            ),
            if (_custom) ...[
              Row(children: [
                Expanded(
                  child: Slider(
                    value: _customMinutes.toDouble(),
                    min: _customMin.toDouble(),
                    max: _customMax.toDouble(),
                    divisions: (_customMax - _customMin) ~/ _customStep,
                    label: l.minutes(_customMinutes),
                    onChanged: (v) => setState(() => _minutes = _customMinutes = v.round()),
                  ),
                ),
                SizedBox(width: 72, child: Text(l.minutes(_customMinutes), style: t.bodyMedium)),
              ]),
              Text(l.breathLongNote, style: t.bodySmall),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(l.breathBells, style: t.bodyMedium),
              subtitle: Text(l.breathBellsSub, style: t.bodySmall),
              value: _bells,
              onChanged: (v) => setState(() => _bells = v),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Row(children: [
                Flexible(child: Text(l.breathBinaural, style: t.bodyMedium)),
                if (!_s.isPremium) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.lock_outline, size: 16),
                ],
              ]),
              subtitle: Text(l.breathBinauralSub, style: t.bodySmall),
              value: _binaural,
              onChanged: (v) => (v && !_s.isPremium) ? _unlock(() => _binaural = true) : setState(() => _binaural = v),
            ),
            if (_binaural)
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  for (final c in BinauralCarrier.values)
                    ChoiceChip(
                      label: Text(switch (c) {
                        BinauralCarrier.c128 => l.breathCarrier128,
                        BinauralCarrier.a216 => l.breathCarrier216,
                      }),
                      selected: _carrier == c,
                      onSelected: (_) => setState(() => _carrier = c),
                    ),
                ],
              ),
            const SizedBox(height: 4),
            Text(l.breathHeadphones, style: t.bodySmall),
            const SizedBox(height: 16),
            Center(
              child: FilledButton(
                onPressed: () {
                  _lastMinutes = _minutes;
                  _lastCustom = _customMinutes;
                  _lastBells = _bells;
                  _lastBinaural = _binaural;
                  _lastCarrier = _carrier;
                  Navigator.of(context).pop(SessionSpec(
                    upper: beds.upper,
                    lower: beds.lower,
                    minutes: _minutes,
                    bells: _bells,
                    binaural: _binaural,
                    carrier: _carrier,
                  ));
                },
                child: Text(l.breathStart),
              ),
            ),
          ],
      ),
    );
  }
}
