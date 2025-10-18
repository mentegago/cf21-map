import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/map_screen.dart';
import 'services/favorites_service.dart';
import 'services/data_source_manager.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize favorites service to check storage availability
  await FavoritesService.instance.initialize();

  // Initialize data source manager
  final dataSourceManager = DataSourceManager();
  await dataSourceManager.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => dataSourceManager,
      child: const CF21MapApp(),
    ),
  );
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
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        // Match map dark background so empty/panned areas are the same color
        scaffoldBackgroundColor: const Color(0xFF0A1B2A),
        fontFamily: 'Roboto',
      ),
      themeMode: ThemeMode.system,
      home: const MapScreen(),
    );
  }
}
