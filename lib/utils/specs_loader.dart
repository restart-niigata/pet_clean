import 'dart:convert';
import 'package:flutter/services.dart';

class SpecsLoader {
  List<String> species = [];
  List<String> personalities = [];
  List<String> moods = [];

  static final SpecsLoader _instance = SpecsLoader._internal();
  factory SpecsLoader() => _instance;
  SpecsLoader._internal();

  Future<void> loadSpecs() async {
    final String jsonString = await rootBundle.loadString('assets/templates/specs.json');
    final Map<String, dynamic> jsonMap = json.decode(jsonString);
    species = List<String>.from(jsonMap['species'] ?? []);
    personalities = List<String>.from(jsonMap['personalities'] ?? []);
    moods = List<String>.from(jsonMap['moods'] ?? []);
  }
}
