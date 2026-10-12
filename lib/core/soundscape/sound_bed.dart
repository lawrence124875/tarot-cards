import '../tarot/tarot_card.dart';

/// 八種程式合成的自然音景（沿用謙卦音景引擎；順序不可改，合成的亂數種子依 index）。
/// 名稱在 l10n（soundscapeName）。
enum SoundBed { sky, lake, fire, thunder, wind, water, mountain, earth }

/// 元素 → 兩層音景（上層、下層）。音景明亮、溫暖（App 精神：光明、療愈、快樂）：
/// 火：營火＋高空清風；水：山澗流水＋湖畔水波；風：林間風聲＋高空清風；土：山林鳥鳴＋夜野蟲鳴。
({SoundBed upper, SoundBed lower}) bedsFor(TarotElement e) => switch (e) {
      TarotElement.fire => (upper: SoundBed.sky, lower: SoundBed.fire),
      TarotElement.water => (upper: SoundBed.lake, lower: SoundBed.water),
      TarotElement.air => (upper: SoundBed.sky, lower: SoundBed.wind),
      TarotElement.earth => (upper: SoundBed.mountain, lower: SoundBed.earth),
    };
