import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  final String? species;
  final String? personality;
  final String? petName;
  final String? ownerName;
  final String? dialect;

  PrefsService({this.species, this.personality, this.petName, this.ownerName, this.dialect});

  static const _kSpecies = 'species';
  static const _kPersonality = 'personality';
  static const _kPetName = 'petName';
  static const _kOwnerName = 'ownerName';
  static const _kDialect = 'dialect';

  static Future<PrefsService> load() async {
    final sp = await SharedPreferences.getInstance();
    return PrefsService(
      species: sp.getString(_kSpecies),
      personality: sp.getString(_kPersonality),
      petName: sp.getString(_kPetName),
      ownerName: sp.getString(_kOwnerName),
      dialect: sp.getString(_kDialect) ?? '標準語',
    );
  }

  static Future<void> save({
    String? species,
    String? personality,
    String? petName,
    String? ownerName,
    String? dialect,
  }) async {
    final sp = await SharedPreferences.getInstance();
    if (species != null) await sp.setString(_kSpecies, species);
    if (personality != null) await sp.setString(_kPersonality, personality);
    if (petName != null) await sp.setString(_kPetName, petName);
    if (ownerName != null) await sp.setString(_kOwnerName, ownerName);
    if (dialect != null) await sp.setString(_kDialect, dialect);
  }
}
