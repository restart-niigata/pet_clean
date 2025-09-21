import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static const _kOwner = 'owner_name';
  static const _kPet = 'pet_name';
  static const _kSpecies = 'species';
  static const _kPersonality = 'personality';
  static const _kDialect = 'dialect';

  static Future<void> save({
    required String owner,
    required String pet,
    required String species,
    required String personality,
    required String dialect,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOwner, owner);
    await p.setString(_kPet, pet);
    await p.setString(_kSpecies, species);
    await p.setString(_kPersonality, personality);
    await p.setString(_kDialect, dialect);
  }

  static Future<Map<String, String>> load() async {
    final p = await SharedPreferences.getInstance();
    return {
      'owner': p.getString(_kOwner) ?? '',
      'pet': p.getString(_kPet) ?? '',
      'species': p.getString(_kSpecies) ?? 'dog',
      'personality': p.getString(_kPersonality) ?? '元気',
      'dialect': p.getString(_kDialect) ?? '標準語',
    };
  }
}
