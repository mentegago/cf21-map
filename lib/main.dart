import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(const CF21MapApp());
}

class CF21MapApp extends StatelessWidget {
  const CF21MapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CF21 Booth Map',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color.fromARGB(255, 247, 247, 247),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        // Match map dark background so empty/panned areas are the same color
        scaffoldBackgroundColor: const Color(0xFF0A1B2A),
      ),
      themeMode: ThemeMode.system,
      home: const MapScreen(),
    );
  }
}
