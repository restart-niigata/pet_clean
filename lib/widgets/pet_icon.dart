import 'package:flutter/material.dart';

class PetIcon extends StatelessWidget {
  const PetIcon(this.assetPath, {super.key, this.size = 24});
  final String assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.pets, size: size, color: Theme.of(context).iconTheme.color),
    );
  }
}
