import 'package:flutter/material.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

