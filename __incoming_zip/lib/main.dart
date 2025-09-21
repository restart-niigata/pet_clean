// lib/main.dart  ――― 全差し替え ―――
import 'package:flutter/material.dart';
import 'package:pet_clean/utils/ad_manager.dart';
import 'pages/name_input_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 起動時に一度だけインタースティシャルを事前ロード（表示はしない）
  await AdManager.loadInterstitial();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: const Color(0xFF78A7FF),
      brightness: Brightness.light,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 18),
        bodyMedium: TextStyle(fontSize: 16),
        labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );

    return MaterialApp(
      title: 'PetClean',
      debugShowCheckedModeBanner: false,
      theme: baseTheme,
      home: const NameInputPage(),
    );
  }
}
