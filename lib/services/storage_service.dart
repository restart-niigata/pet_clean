import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _kOwner = 'owner';
  static const _kPet = 'pet';
  static const _kSpecies = 'species';
  static const _kPersonality = 'personality';
  static const _kDialect = 'dialect';

  static Future<Map<String, String>> loadAll() async {
    final sp = await SharedPreferences.getInstance();
    return {
      'owner': sp.getString(_kOwner) ?? '',
      'pet': sp.getString(_kPet) ?? '',
      'species': sp.getString(_kSpecies) ?? '犬',
      'personality': sp.getString(_kPersonality) ?? '元気',
      'dialect': sp.getString(_kDialect) ?? '標準語',
    };
  }

  static Future<void> saveAll({
    required String owner,
    required String pet,
    required String species,
    required String personality,
    required String dialect,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kOwner, owner);
    await sp.setString(_kPet, pet);
    await sp.setString(_kSpecies, species);
    await sp.setString(_kPersonality, personality);
    await sp.setString(_kDialect, dialect);
  }
}
