// lib/models/personality.dart
// 変更禁止：性格は最終7種
// 元気 / おっとり / クール / 甘えん坊 / 臆病 / おしゃべり / やんちゃ

enum PetPersonality {
  genki,      // 元気
  ottori,     // おっとり
  cool,       // クール
  amaenbo,    // 甘えん坊
  okubyo,     // 臆病
  oshaberi,   // おしゃべり
  yancha,     // やんちゃ
}

extension PetPersonalityLabel on PetPersonality {
  String get label => switch (this) {
        PetPersonality.genki => '元気',
        PetPersonality.ottori => 'おっとり',
        PetPersonality.cool => 'クール',
        PetPersonality.amaenbo => '甘えん坊',
        PetPersonality.okubyo => '臆病',
        PetPersonality.oshaberi => 'おしゃべり',
        PetPersonality.yancha => 'やんちゃ',
      };
}

extension PetPersonalityJsonKey on PetPersonality {
  String get jsonKey => label;
}

extension PetPersonalityOrdered on PetPersonality {
  static List<PetPersonality> get orderedValues => const [
        PetPersonality.genki,
        PetPersonality.ottori,
        PetPersonality.cool,
        PetPersonality.amaenbo,
        PetPersonality.okubyo,
        PetPersonality.oshaberi,
        PetPersonality.yancha,
      ];
  static List<String> get orderedLabels =>
      orderedValues.map((e) => e.label).toList(growable: false);
}

extension PetPersonalityParser on PetPersonality {
  static PetPersonality fromLabel(String? label) {
    const map = {
      '元気': PetPersonality.genki,
      'おっとり': PetPersonality.ottori,
      'クール': PetPersonality.cool,
      '甘えん坊': PetPersonality.amaenbo,
      '臆病': PetPersonality.okubyo,
      'おしゃべり': PetPersonality.oshaberi,
      'やんちゃ': PetPersonality.yancha,
    };
    return map[label] ?? PetPersonality.genki;
  }

  static PetPersonality absorb(String? any) => fromLabel(any);
}

/// Nullを許容しない受け渡し用
String ensurePersonalityLabel(String? label) =>
    PetPersonalityParser.fromLabel(label).label;
