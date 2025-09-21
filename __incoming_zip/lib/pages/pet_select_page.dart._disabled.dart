import 'package:flutter/material.dart';
import 'personality_select_page.dart';

class PetSelectPage extends StatefulWidget {
  const PetSelectPage({super.key});

  @override
  State<PetSelectPage> createState() => _PetSelectPageState();
}

class _PetSelectPageState extends State<PetSelectPage> {
  String? selectedSpecies;

  final List<String> speciesList = [
    '犬',
    '猫',
  ];

  void _goToPersonalitySelect() {
    if (selectedSpecies != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PersonalitySelectPage(species: selectedSpecies!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ペットを選んでください'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: speciesList
                  .map(
                    (species) => RadioListTile<String>(
                      title: Text(species),
                      value: species,
                      groupValue: selectedSpecies,
                      onChanged: (value) {
                        setState(() {
                          selectedSpecies = value;
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          ElevatedButton(
            onPressed: _goToPersonalitySelect,
            child: const Text('つぎへ'),
          ),
        ],
      ),
    );
  }
}
