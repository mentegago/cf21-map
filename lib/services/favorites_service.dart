import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/creator.dart';

class FavoritesService {
  static const String _favoritesKey = 'favorite_creators';
  static FavoritesService? _instance;
  static SharedPreferences? _prefs;

  // Singleton pattern
  static FavoritesService get instance {
    _instance ??= FavoritesService._();
    return _instance!;
  }

  FavoritesService._();

  // Initialize SharedPreferences
  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Add a creator to favorites
  /// Returns true if successfully added, false if already exists
  Future<bool> addFavorite(Creator creator) async {
    await _initPrefs();
    
    final favorites = await getFavorites();
    
    // Check if creator is already in favorites
    if (favorites.any((fav) => fav.name == creator.name)) {
      return false;
    }
    
    // Add creator to favorites
    favorites.add(creator);
    
    // Save to persistent storage
    await _saveFavorites(favorites);
    return true;
  }

  /// Remove a creator from favorites
  /// Returns true if successfully removed, false if not found
  Future<bool> removeFavorite(String creatorName) async {
    await _initPrefs();
    
    final favorites = await getFavorites();
    
    // Find and remove the creator
    final initialLength = favorites.length;
    favorites.removeWhere((creator) => creator.name == creatorName);
    
    // If length changed, creator was removed
    if (favorites.length < initialLength) {
      await _saveFavorites(favorites);
      return true;
    }
    
    return false;
  }

  /// Get all favorited creators, sorted by name
  Future<List<Creator>> getFavorites() async {
    await _initPrefs();
    
    final favoritesJson = _prefs!.getStringList(_favoritesKey) ?? [];
    
    // Convert JSON strings back to Creator objects
    final favorites = favoritesJson
        .map((jsonString) => Creator.fromJson(jsonDecode(jsonString)))
        .toList();
    
    // Sort by name (case-insensitive)
    favorites.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    
    return favorites;
  }

  /// Check if a creator is favorited
  Future<bool> isFavorite(String creatorName) async {
    final favorites = await getFavorites();
    return favorites.any((creator) => creator.name == creatorName);
  }

  /// Clear all favorites
  Future<void> clearFavorites() async {
    await _initPrefs();
    await _prefs!.remove(_favoritesKey);
  }

  /// Get the number of favorited creators
  Future<int> getFavoriteCount() async {
    final favorites = await getFavorites();
    return favorites.length;
  }

  /// Save favorites to persistent storage
  Future<void> _saveFavorites(List<Creator> favorites) async {
    await _initPrefs();
    
    // Convert Creator objects to JSON strings
    final favoritesJson = favorites
        .map((creator) => jsonEncode(_creatorToJson(creator)))
        .toList();
    
    await _prefs!.setStringList(_favoritesKey, favoritesJson);
  }

  /// Convert Creator object to JSON-compatible Map
  Map<String, dynamic> _creatorToJson(Creator creator) {
    return {
      'name': creator.name,
      'booths': creator.booths,
      'day': creator.day,
      'profileImage': creator.profileImage,
      'informations': creator.informations
          .map((info) => {
                'title': info.title,
                'content': info.content,
              })
          .toList(),
      'urls': creator.urls
          .map((url) => {
                'title': url.title,
                'url': url.url,
              })
          .toList(),
    };
  }
}
