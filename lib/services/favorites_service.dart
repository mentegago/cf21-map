import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/creator.dart';
import 'creator_data_service.dart';

class FavoritesService extends ChangeNotifier {
  static const String _favoritesKey = 'favorite_creators';
  static const String _favoritesIdsKey = 'favorite_creator_ids';
  static const String _migrationKey = 'favorites_migrated';
  static SharedPreferences? _prefs;

  // Local state for fast synchronous access
  final Set<int> _favoriteIds = <int>{};
  
  // Debounce timer for storage updates
  Timer? _storageUpdateTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 500);

  CreatorDataProvider creatorDataProvider;

  FavoritesService(this.creatorDataProvider);

  List<Creator> get favorites {
    final favoriteCreators = <Creator>[];
    for (final id in _favoriteIds) {
      final creator = creatorDataProvider.getCreatorById(id);
      if (creator != null) {
        favoriteCreators.add(creator);
      }
    }
    
    return favoriteCreators;
  }

  // Synchronous methods for fast access
  void addFavorite(int creatorId) {
    if (_favoriteIds.add(creatorId)) {
      notifyListeners();
      _scheduleStorageUpdate();
    }
  }

  void removeFavorite(int creatorId) {
    if (_favoriteIds.remove(creatorId)) {
      notifyListeners();
      _scheduleStorageUpdate();
    }
  }

  bool isFavorited(int creatorId) {
    return _favoriteIds.contains(creatorId);
  }

  // Debounced storage update
  void _scheduleStorageUpdate() {
    _storageUpdateTimer?.cancel();
    _storageUpdateTimer = Timer(_debounceDelay, () {
      _updateStorage();
    });
  }

  // Asynchronous storage update
  Future<void> _updateStorage() async {
    await _initPrefs();
    if (_prefs == null) return;
    
    try {
      await _prefs!.setStringList(
        _favoritesIdsKey, 
        _favoriteIds.map((id) => id.toString()).toList()
      );
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save favorite IDs: $e');
      }
    }
  }

  // Initialize SharedPreferences
  Future<void> _initPrefs() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      // Run migration if needed
      await _migrateFavoritesIfNeeded();
    } catch (e) {
      // Handle cases where SharedPreferences is not available (e.g., HTTP, private browsing)
      if (kDebugMode) {
        print('SharedPreferences initialization failed: $e');
      }
      // Create a mock SharedPreferences that doesn't persist
      _prefs = null;
    }
  }

  /// Migrate old favorites (full Creator objects) to new ID-based system
  Future<void> _migrateFavoritesIfNeeded() async {
    if (_prefs == null) return;
    
    final migrated = _prefs!.getBool(_migrationKey) ?? false;
    if (migrated) return;
    
    try {
      final oldFavoritesJson = _prefs!.getStringList(_favoritesKey) ?? [];
      if (oldFavoritesJson.isNotEmpty) {
        // Convert old favorites to IDs
        final favoriteIds = <int>[];
        for (final jsonString in oldFavoritesJson) {
          try {
            final creatorJson = jsonDecode(jsonString) as Map<String, dynamic>;
            final id = creatorJson['id'] as int?;
            if (id != null) {
              favoriteIds.add(id);
            }
          } catch (e) {
            if (kDebugMode) {
              print('Failed to migrate favorite: $e');
            }
          }
        }
        
        // Save new ID-based favorites
        if (favoriteIds.isNotEmpty) {
          await _prefs!.setStringList(_favoritesIdsKey, favoriteIds.map((id) => id.toString()).toList());
          if (kDebugMode) {
            print('Migrated ${favoriteIds.length} favorites to ID-based system');
          }
        }
      }
      
      // Mark migration as complete
      await _prefs!.setBool(_migrationKey, true);
      
      // Clean up old favorites data
      await _prefs!.remove(_favoritesKey);
      
    } catch (e) {
      if (kDebugMode) {
        print('Migration failed: $e');
      }
    }
  }


  /// Get favorite creator IDs
  Future<List<int>> _getFavoriteIds() async {
    await _initPrefs();
    
    if (_prefs == null) {
      return [];
    }
    
    final idsJson = _prefs!.getStringList(_favoritesIdsKey) ?? [];
    return idsJson.map((idString) => int.tryParse(idString)).whereType<int>().toList();
  }

  @override
  void dispose() {
    _storageUpdateTimer?.cancel();
    super.dispose();
  }

  /// Get the number of favorited creators
  int get favoriteCount => _favoriteIds.length;

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
    
    // Load favorites from storage into local state
    final favoriteIds = await _getFavoriteIds();
    _favoriteIds.clear();
    _favoriteIds.addAll(favoriteIds);
    
    if (kDebugMode) {
      print('FavoritesService: $storageStatus, loaded ${_favoriteIds.length} favorites');
    }
  }
}

