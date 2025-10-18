import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/map_screen.dart';
import 'services/favorites_service.dart';
import 'services/creator_data_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final creatorDataProvider = CreatorDataProvider()..initialize();
  final favoritesService = FavoritesService(creatorDataProvider)..initialize();
  
  runApp(CF21MapApp(creatorDataProvider: creatorDataProvider, favoritesService: favoritesService));
}

class CF21MapApp extends StatelessWidget {

  final CreatorDataProvider creatorDataProvider;
  final FavoritesService favoritesService;

  const CF21MapApp({super.key, required this.creatorDataProvider, required this.favoritesService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) => creatorDataProvider,
        ),
        ChangeNotifierProvider(
          create: (context) => favoritesService,
        ),
      ],
      child: MaterialApp(
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
      ),
    );
  }
}
