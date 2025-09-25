// lib/main.dart
import 'package:flutter/material.dart';
import 'pages/name_input_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PetCleanApp());
}

class PetCleanApp extends StatelessWidget {
  const PetCleanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetClean',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4C72FF)),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 18),
          titleLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          labelLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      home: const NameInputPage(),
    );
  }
}
