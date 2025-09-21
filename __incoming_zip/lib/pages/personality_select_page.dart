import 'package:flutter/material.dart';
import 'preview_page.dart';

class PersonalitySelectPage extends StatelessWidget {
  final String ownerName;
  final String petName;
  final String species;

  const PersonalitySelectPage({
    super.key,
    required this.ownerName,
    required this.petName,
    required this.species,
  });

  static const personalities = [
    '元気','おっとり','クール','甘えん坊','臆病','おしゃべり','やんちゃ',
  ];

  void _goPreview(BuildContext context, String personality) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PreviewPage(
        ownerName: ownerName,
        petName: petName,
        species: species,
        personality: personality,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final chips = personalities.map((p) {
      return ActionChip(
        label: Text(p),
        onPressed: () => _goPreview(context, p),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('性格をえらんでね')),
      body: Center(
        child: Wrap(
          spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
          children: chips,
        ),
      ),
    );
  }
}
