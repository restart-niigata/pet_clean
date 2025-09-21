import 'package:flutter/material.dart';

class SelectionProvider extends ChangeNotifier {
  String? _selectedSpecies;

  String? get selectedSpecies => _selectedSpecies;

  void setSelectedSpecies(String species) {
    _selectedSpecies = species;
    notifyListeners();
  }
}
