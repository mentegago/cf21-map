import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/creator.dart';

class FavoritesService extends ChangeNotifier {
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
    try {
      _prefs ??= await SharedPreferences.getInstance();
    } catch (e) {
      // Handle cases where SharedPreferences is not available (e.g., HTTP, private browsing)
      if (kDebugMode) {
        print('SharedPreferences initialization failed: $e');
      }
      // Create a mock SharedPreferences that doesn't persist
      _prefs = null;
    }
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
    
    // Notify listeners of the change
    notifyListeners();
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
      
      // Notify listeners of the change
      notifyListeners();
      return true;
    }
    
    return false;
  }

  /// Get all favorited creators, sorted by name
  Future<List<Creator>> getFavorites() async {
    await _initPrefs();
    
    // If SharedPreferences is not available, return empty list
    if (_prefs == null) {
      return [];
    }
    
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
    
    if (_prefs != null) {
      try {
        await _prefs!.remove(_favoritesKey);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to clear favorites: $e');
        }
      }
    }
    
    // Notify listeners of the change
    notifyListeners();
  }

  /// Get the number of favorited creators
  Future<int> getFavoriteCount() async {
    final favorites = await getFavorites();
    return favorites.length;
  }

  /// Check if persistent storage is available
  bool get isStorageAvailable => _prefs != null;

  /// Get storage availability status for debugging
  String get storageStatus {
    if (_prefs == null) {
      return 'Storage not available (HTTP/Private browsing)';
    }
    return 'Storage available';
  }

  /// Initialize and check storage availability
  Future<void> initialize() async {
    await _initPrefs();
    if (kDebugMode) {
      print('FavoritesService: ${storageStatus}');
    }
  }

  /// Save favorites to persistent storage
  Future<void> _saveFavorites(List<Creator> favorites) async {
    await _initPrefs();
    
    // If SharedPreferences is not available, skip saving
    if (_prefs == null) {
      if (kDebugMode) {
        print('Cannot save favorites: SharedPreferences not available');
      }
      return;
    }
    
    // Convert Creator objects to JSON strings
    final favoritesJson = favorites
        .map((creator) => jsonEncode(_creatorToJson(creator)))
        .toList();
    
    try {
      await _prefs!.setStringList(_favoritesKey, favoritesJson);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save favorites: $e');
      }
    }
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
