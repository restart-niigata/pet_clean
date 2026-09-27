import 'package:shared_preferences/shared_preferences.dart';

class PetVoiceProfile {
  const PetVoiceProfile({
    required this.preset,
    required this.firstPerson,
    required this.ending,
    required this.ownerCall,
  });

  static const presetOptions = [
    '元気',
    'おっとり',
    'クール',
    '甘えん坊',
    '臆病',
    'おしゃべり',
    'やんちゃ',
    'ツンデレ',
  ];
  static const firstPersonOptions = ['ぼく', 'わたし', 'おれ', 'あたし', '自分'];
  static const endingOptions = ['', 'だよ', 'だね', 'なの', 'ワン', 'にゃ'];

  static const _presetKey = 'pet_voice.preset.v1';
  static const _firstPersonKey = 'pet_voice.first_person.v1';
  static const _endingKey = 'pet_voice.ending.v1';
  static const _ownerCallKey = 'pet_voice.owner_call.v1';

  final String preset;
  final String firstPerson;
  final String ending;
  final String ownerCall;

  static Future<PetVoiceProfile> load({
    required String defaultPreset,
    required String ownerName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return PetVoiceProfile(
      preset: prefs.getString(_presetKey) ?? defaultPreset,
      firstPerson: prefs.getString(_firstPersonKey) ?? 'ぼく',
      ending: prefs.getString(_endingKey) ?? '',
      ownerCall: prefs.getString(_ownerCallKey) ??
          (ownerName.trim().isEmpty ? '飼い主さん' : ownerName.trim()),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_presetKey, preset),
      prefs.setString(_firstPersonKey, firstPerson),
      prefs.setString(_endingKey, ending),
      prefs.setString(_ownerCallKey, ownerCall.trim()),
    ]);
  }
}
