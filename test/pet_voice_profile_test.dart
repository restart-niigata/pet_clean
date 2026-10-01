import 'package:pet_clean/models/pet_voice_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

void main() {
  test('loads defaults and persists voice choices', () async {
    SharedPreferences.setMockInitialValues({});
    final defaults = await PetVoiceProfile.load(
      defaultPreset: '元気',
      ownerName: 'みき',
    );
    expect(defaults.preset, '元気');
    expect(defaults.firstPerson, 'ぼく');
    expect(defaults.ownerCall, 'みき');

    const saved = PetVoiceProfile(
      preset: 'ツンデレ',
      firstPerson: 'おれ',
      ending: 'ワン',
      ownerCall: 'ご主人',
    );
    await saved.save();
    final loaded = await PetVoiceProfile.load(
      defaultPreset: '元気',
      ownerName: 'みき',
    );
    expect(loaded.preset, 'ツンデレ');
    expect(loaded.firstPerson, 'おれ');
    expect(loaded.ending, 'ワン');
    expect(loaded.ownerCall, 'ご主人');
  });
}
