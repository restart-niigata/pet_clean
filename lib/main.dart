// lib/main.dart
import 'package:flutter/material.dart';
import 'pages/legal_gate.dart';
import 'pages/name_input_page.dart';
import 'services/ad_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PetCleanApp());
}

class PetCleanApp extends StatelessWidget {
  const PetCleanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ぺっとーく',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4C72FF)),
        useMaterial3: true,
        // Webビルドでも外部シェーダーに依存しない標準リップルを使う。
        splashFactory: InkRipple.splashFactory,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 18),
          titleLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      home: LegalGate(
        onAccepted: AdService.initialize,
        child: const NameInputPage(),
      ),
    );
  }
}
