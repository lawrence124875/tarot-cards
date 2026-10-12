/// 78 張牌的名稱（11 語）。大阿爾克那逐張列出；小阿爾克那由「牌階樣板」套入花色名組成（{s}＝花色）。
/// 名稱是學習用的通行譯名（各語言塔羅書與牌組的常見叫法）；不用商標名「Rider-Waite」。
/// 畫面不直接用本檔，一律經過 TarotTerms（terms.dart）。
class CardNames {
  const CardNames._(this.majors, this.suits, this.ranks);

  /// 0–21。
  final List<String> majors;

  /// 權杖、聖杯、寶劍、錢幣。
  final List<String> suits;

  /// Ace、2–10、侍者、騎士、皇后、國王的樣板（{s}＝花色名）。
  final List<String> ranks;

  static const fallback = 'zh-Hant';

  static CardNames of(String code) => _names[code] ?? _names[fallback]!;

  static Iterable<String> get languages => _names.keys;

  String card(int id) {
    if (id < 22) return majors[id];
    final suit = (id - 22) ~/ 14, rank = (id - 22) % 14;
    return ranks[rank].replaceAll('{s}', suits[suit]);
  }
}

const _names = <String, CardNames>{
  'zh-Hant': CardNames._(
    ['愚者', '魔術師', '女祭司', '皇后', '皇帝', '教皇', '戀人', '戰車', '力量', '隱者', '命運之輪',
     '正義', '倒吊人', '死神', '節制', '惡魔', '高塔', '星星', '月亮', '太陽', '審判', '世界'],
    ['權杖', '聖杯', '寶劍', '錢幣'],
    ['{s}王牌', '{s}二', '{s}三', '{s}四', '{s}五', '{s}六', '{s}七', '{s}八', '{s}九', '{s}十',
     '{s}侍者', '{s}騎士', '{s}皇后', '{s}國王'],
  ),
  'zh-Hans': CardNames._(
    ['愚者', '魔术师', '女祭司', '皇后', '皇帝', '教皇', '恋人', '战车', '力量', '隐者', '命运之轮',
     '正义', '倒吊人', '死神', '节制', '恶魔', '高塔', '星星', '月亮', '太阳', '审判', '世界'],
    ['权杖', '圣杯', '宝剑', '钱币'],
    ['{s}王牌', '{s}二', '{s}三', '{s}四', '{s}五', '{s}六', '{s}七', '{s}八', '{s}九', '{s}十',
     '{s}侍从', '{s}骑士', '{s}王后', '{s}国王'],
  ),
  'en': CardNames._(
    ['The Fool', 'The Magician', 'The High Priestess', 'The Empress', 'The Emperor', 'The Hierophant',
     'The Lovers', 'The Chariot', 'Strength', 'The Hermit', 'Wheel of Fortune', 'Justice', 'The Hanged Man',
     'Death', 'Temperance', 'The Devil', 'The Tower', 'The Star', 'The Moon', 'The Sun', 'Judgement', 'The World'],
    ['Wands', 'Cups', 'Swords', 'Pentacles'],
    ['Ace of {s}', 'Two of {s}', 'Three of {s}', 'Four of {s}', 'Five of {s}', 'Six of {s}', 'Seven of {s}',
     'Eight of {s}', 'Nine of {s}', 'Ten of {s}', 'Page of {s}', 'Knight of {s}', 'Queen of {s}', 'King of {s}'],
  ),
  'ja': CardNames._(
    ['愚者', '魔術師', '女教皇', '女帝', '皇帝', '教皇', '恋人', '戦車', '力', '隠者', '運命の輪',
     '正義', '吊るされた男', '死神', '節制', '悪魔', '塔', '星', '月', '太陽', '審判', '世界'],
    ['ワンド', 'カップ', 'ソード', 'ペンタクル'],
    ['{s}のエース', '{s}の2', '{s}の3', '{s}の4', '{s}の5', '{s}の6', '{s}の7', '{s}の8', '{s}の9', '{s}の10',
     '{s}のペイジ', '{s}のナイト', '{s}のクイーン', '{s}のキング'],
  ),
  'ko': CardNames._(
    ['바보', '마법사', '여사제', '여황제', '황제', '교황', '연인', '전차', '힘', '은둔자', '운명의 수레바퀴',
     '정의', '매달린 사람', '죽음', '절제', '악마', '탑', '별', '달', '태양', '심판', '세계'],
    ['완드', '컵', '소드', '펜타클'],
    ['{s} 에이스', '{s} 2', '{s} 3', '{s} 4', '{s} 5', '{s} 6', '{s} 7', '{s} 8', '{s} 9', '{s} 10',
     '{s} 페이지', '{s} 나이트', '{s} 퀸', '{s} 킹'],
  ),
  'vi': CardNames._(
    ['Chàng Khờ', 'Nhà Ảo Thuật', 'Nữ Tư Tế', 'Hoàng Hậu', 'Hoàng Đế', 'Giáo Hoàng', 'Tình Nhân', 'Cỗ Xe',
     'Sức Mạnh', 'Ẩn Sĩ', 'Bánh Xe Số Phận', 'Công Lý', 'Người Treo Ngược', 'Cái Chết', 'Tiết Chế', 'Ác Quỷ',
     'Tòa Tháp', 'Ngôi Sao', 'Mặt Trăng', 'Mặt Trời', 'Phán Xét', 'Thế Giới'],
    ['Gậy', 'Cốc', 'Kiếm', 'Tiền'],
    ['Át {s}', 'Hai {s}', 'Ba {s}', 'Bốn {s}', 'Năm {s}', 'Sáu {s}', 'Bảy {s}', 'Tám {s}', 'Chín {s}', 'Mười {s}',
     'Tiểu Đồng {s}', 'Hiệp Sĩ {s}', 'Nữ Hoàng {s}', 'Vua {s}'],
  ),
  'id': CardNames._(
    ['Si Pengelana Polos', 'Sang Pesulap', 'Pendeta Agung Wanita', 'Sang Permaisuri', 'Sang Kaisar',
     'Sang Imam Agung', 'Sang Kekasih', 'Kereta Perang', 'Kekuatan', 'Sang Pertapa', 'Roda Keberuntungan',
     'Keadilan', 'Orang yang Tergantung', 'Kematian', 'Keseimbangan', 'Iblis', 'Menara', 'Bintang', 'Bulan',
     'Matahari', 'Kebangkitan', 'Dunia'],
    ['Tongkat', 'Cawan', 'Pedang', 'Pentakel'],
    ['As {s}', 'Dua {s}', 'Tiga {s}', 'Empat {s}', 'Lima {s}', 'Enam {s}', 'Tujuh {s}', 'Delapan {s}',
     'Sembilan {s}', 'Sepuluh {s}', 'Pelayan {s}', 'Ksatria {s}', 'Ratu {s}', 'Raja {s}'],
  ),
  'es': CardNames._(
    ['El Loco', 'El Mago', 'La Sacerdotisa', 'La Emperatriz', 'El Emperador', 'El Hierofante', 'Los Enamorados',
     'El Carro', 'La Fuerza', 'El Ermitaño', 'La Rueda de la Fortuna', 'La Justicia', 'El Colgado', 'La Muerte',
     'La Templanza', 'El Diablo', 'La Torre', 'La Estrella', 'La Luna', 'El Sol', 'El Juicio', 'El Mundo'],
    ['Bastos', 'Copas', 'Espadas', 'Pentáculos'],
    ['As de {s}', 'Dos de {s}', 'Tres de {s}', 'Cuatro de {s}', 'Cinco de {s}', 'Seis de {s}', 'Siete de {s}',
     'Ocho de {s}', 'Nueve de {s}', 'Diez de {s}', 'Sota de {s}', 'Caballero de {s}', 'Reina de {s}', 'Rey de {s}'],
  ),
  'pt-BR': CardNames._(
    ['O Louco', 'O Mago', 'A Sacerdotisa', 'A Imperatriz', 'O Imperador', 'O Hierofante', 'Os Enamorados',
     'O Carro', 'A Força', 'O Eremita', 'A Roda da Fortuna', 'A Justiça', 'O Enforcado', 'A Morte',
     'A Temperança', 'O Diabo', 'A Torre', 'A Estrela', 'A Lua', 'O Sol', 'O Julgamento', 'O Mundo'],
    ['Paus', 'Copas', 'Espadas', 'Pentáculos'],
    ['Ás de {s}', 'Dois de {s}', 'Três de {s}', 'Quatro de {s}', 'Cinco de {s}', 'Seis de {s}', 'Sete de {s}',
     'Oito de {s}', 'Nove de {s}', 'Dez de {s}', 'Valete de {s}', 'Cavaleiro de {s}', 'Rainha de {s}', 'Rei de {s}'],
  ),
  'th': CardNames._(
    ['คนเขลา', 'นักมายากล', 'นักบวชหญิงชั้นสูง', 'จักรพรรดินี', 'จักรพรรดิ', 'สังฆราช', 'คู่รัก', 'รถศึก',
     'พลัง', 'ฤๅษี', 'กงล้อแห่งโชคชะตา', 'ความยุติธรรม', 'ชายผู้ถูกแขวน', 'ความตาย', 'ความพอดี', 'ปีศาจ',
     'หอคอย', 'ดวงดาว', 'ดวงจันทร์', 'ดวงอาทิตย์', 'การพิพากษา', 'โลก'],
    ['ไม้เท้า', 'ถ้วย', 'ดาบ', 'เหรียญ'],
    ['เอซแห่ง{s}', 'สองแห่ง{s}', 'สามแห่ง{s}', 'สี่แห่ง{s}', 'ห้าแห่ง{s}', 'หกแห่ง{s}', 'เจ็ดแห่ง{s}',
     'แปดแห่ง{s}', 'เก้าแห่ง{s}', 'สิบแห่ง{s}', 'เด็กรับใช้แห่ง{s}', 'อัศวินแห่ง{s}', 'ราชินีแห่ง{s}', 'ราชาแห่ง{s}'],
  ),
  'ar': CardNames._(
    ['الأحمق', 'الساحر', 'الكاهنة العليا', 'الإمبراطورة', 'الإمبراطور', 'الكاهن الأعظم', 'العاشقان', 'العربة',
     'القوة', 'الناسك', 'عجلة الحظ', 'العدالة', 'الرجل المعلّق', 'الموت', 'الاعتدال', 'الشيطان', 'البرج',
     'النجمة', 'القمر', 'الشمس', 'البعث', 'العالم'],
    ['العصي', 'الكؤوس', 'السيوف', 'العملات'],
    ['آس {s}', 'اثنان من {s}', 'ثلاثة من {s}', 'أربعة من {s}', 'خمسة من {s}', 'ستة من {s}', 'سبعة من {s}',
     'ثمانية من {s}', 'تسعة من {s}', 'عشرة من {s}', 'غلام {s}', 'فارس {s}', 'ملكة {s}', 'ملك {s}'],
  ),
};
