import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'screens/map_screen.dart';

void main() {
  runApp(const CF21MapApp());
  _primeOfflineCache();
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
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
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

// Proactively cache all app assets for offline (PWA) after first load.
void _primeOfflineCache() {
  if (!kIsWeb) return;
  try {
    html.window.navigator.serviceWorker?.ready.then((_) {
      html.window.navigator.serviceWorker?.controller?.postMessage('downloadOffline');
    });
  } catch (_) {
    // Ignore if service worker is unavailable (e.g., debug mode)
  }
}

