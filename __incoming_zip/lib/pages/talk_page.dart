// lib/pages/splash_to_preview.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'preview_page.dart';

class SplashToPreview extends StatefulWidget {
  final String owner;
  final String pet;
  final String species;
  final String personality;
  final String dialect;

  const SplashToPreview({
    super.key,
    required this.owner,
    required this.pet,
    required this.species,
    required this.personality,
    required this.dialect,
  });

  @override
  State<SplashToPreview> createState() => _SplashToPreviewState();
}

class _SplashToPreviewState extends State<SplashToPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260))
        ..forward();

  @override
  void initState() {
    super.initState();
    // 「もう少し長め」1.6秒
    Future.delayed(const Duration(milliseconds: 1600), _go);
  }

  void _go() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PreviewPage(
        ownerName: widget.owner,
        petName: widget.pet,
        species: widget.species,
        personality: widget.personality,
        dialect: widget.dialect,
      ),
    ));
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _ac, curve: Curves.easeIn),
        child: SizedBox.expand(
          child: Image.asset(
            'assets/images/top_pet.png',
            fit: BoxFit.cover, // 全画面
          ),
        ),
      ),
    );
  }
}
