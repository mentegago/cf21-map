import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/creator.dart';
import 'version_service.dart';

enum CreatorDataStatus {
  idle,
  loading,
  updating,
  updated,
  error,
}

class CreatorDataProvider extends ChangeNotifier {
  static const String _dataUrl = 'https://cf21-config.nnt.gg/data/creator-data.json';
  static const String _cachedDataKey = 'cached_creator_data';

  // State properties
  List<Creator>? _creators;
  Map<String, List<Creator>>? _boothToCreators;
  Map<String, List<Creator>>? _boothToCreatorCustomList;
  Map<int, Creator>? _creatorById;
  bool _isLoading = true;
  String? _error;
  CreatorDataStatus _status = CreatorDataStatus.idle;
  Timer? _updateTimer;
  Creator? _selectedCreator;
  List<int>? _creatorCustomListIds;
  List<Creator>? _creatorCustomList;

  Function? _onInitialized;

  // Getters
  List<Creator>? get creators {
    if (isCreatorCustomListMode) return creatorCustomList;
    return _creators;
  }
  
  Map<String, List<Creator>>? get boothToCreators => _boothToCreators;
  Map<String, List<Creator>>? get boothToCreatorCustomList => _boothToCreatorCustomList;
  bool get isLoading => _isLoading;
  String? get error => _error;
  CreatorDataStatus get status => _status;
  Creator? get selectedCreator => _selectedCreator;
  List<Creator>? get creatorCustomList => _creatorCustomList;
  bool get isCreatorCustomListMode => _creatorCustomListIds != null;

  void onCreatorDataServiceInitialized(Function callback) {
    _onInitialized = callback;

    if (!_isLoading) {
      _onInitialized?.call();
    }
  }

  /// Set the currently selected creator (for preservation during updates)
  void setSelectedCreator(Creator? creator) {
    _selectedCreator = creator;
    notifyListeners();
  }

  void selectRandomCreator() {
    if (creators == null || creators!.isEmpty) return;

    final creator = creators![Random().nextInt(creators!.length)];
    setSelectedCreator(creator);
  }

  void setCreatorCustomList(List<int> creatorIds) {
    _creatorCustomListIds = creatorIds;

    if (_creatorById == null) return;

    _creatorCustomList = creatorIds.map((id) => _creatorById![id]).nonNulls.toList();
    _boothToCreatorCustomList = _buildBoothMapping(_creatorCustomList!);
    
    notifyListeners();
  }

  void clearCreatorCustomList() {
    _creatorCustomListIds = null;
    _creatorCustomList = null;
    _boothToCreatorCustomList = null;

    if (kIsWeb) {
      html.window.history.pushState(null, '', '/');
    }

    notifyListeners();
  }

  /// Initialize the provider by loading creator data
  Future<void> initialize() async {
    try {
      _setLoading(true);
      _setError(null);
      
      // Load initial data from cache or assets
      await _loadInitialData();
      
      // Start periodic update checking
      _startPeriodicUpdateCheck();
      
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
      _onInitialized?.call();
    }
  }

  /// Load initial creator data from cache or fallback to bundled assets
  Future<void> _loadInitialData() async {
    // Get versions for comparison
    final cachedVersion = await _getCachedVersion();
    final bundledVersion = await _getBundledVersion();
    
    // If we have cached data and it's newer or equal to bundled, use cached
    if (cachedVersion != null && bundledVersion != null && cachedVersion >= bundledVersion) {
      final cachedCreators = await _getCachedCreatorData();
      if (cachedCreators != null && cachedCreators.isNotEmpty) {
        // Sort cached creators by name
        final sortedCreators = List<Creator>.from(cachedCreators);
        sortedCreators.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _setCreators(sortedCreators);
        return;
      }
    }

    // Load bundled data (either no cache, or bundled is newer)
    final jsonString = await rootBundle.loadString('data/creator-data-initial.json');
    final dynamic jsonData = json.decode(jsonString);
    
    // Handle new JSON structure with version and creators array, and sort by name
    final List<dynamic> creatorsJson = jsonData['creators'] as List<dynamic>;
    final creators = creatorsJson.map((json) => Creator.fromJson(json)).toList();
    creators.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _setCreators(creators);
    
    // Cache the bundled data so it's treated the same as cached data
    await _cacheCreatorData(jsonData);
    print('Loaded bundled creator data (version ${bundledVersion ?? 'unknown'})');
  }

  /// Start periodic update checking (every hour)
  void _startPeriodicUpdateCheck() {
    _updateTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _checkForUpdates();
    });
    _checkForUpdates();
  }

  /// Check for creator data updates
  Future<void> _checkForUpdates() async {
    try {
      // Fetch version info
      final versionInfo = await VersionService.fetchVersionInfo();
      if (versionInfo == null) {
        return;
      }

      // Check if remote version is newer
      final isNewer = await _isRemoteVersionNewer(versionInfo.creatorDataVersion);
      if (!isNewer) return;

      // Update creator data
      await _updateCreatorData();
    } catch (e) {
      print('Error checking for updates: $e');
    }
  }

  /// Update creator data from remote server
  Future<void> _updateCreatorData() async {
    try {
      _setStatus(CreatorDataStatus.updating);
      
      // Fetch new creator data
      final newCreators = await _fetchRemoteCreatorData();
      if (newCreators == null || newCreators.isEmpty) {
        _setStatus(CreatorDataStatus.idle);
        return;
      }

      // Sort creators by name
      final sortedCreators = List<Creator>.from(newCreators);
      sortedCreators.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Check if current selection still exists in new data
      Creator? preservedSelection;
      if (_selectedCreator != null) {
        try {
          preservedSelection = sortedCreators.firstWhere(
            (c) => c.id == _selectedCreator!.id,
          );
        } catch (e) {
          // Creator no longer exists, will clear selection
          _selectedCreator = null;
        }
      }

      // Update creators and booth mapping
      _setCreators(sortedCreators);
      
      // Restore preserved selection if it still exists
      if (preservedSelection != null) {
        _selectedCreator = preservedSelection;
      }
      
      _setStatus(CreatorDataStatus.updated);
      
    } catch (e) {
      print('Error updating creator data: $e');
      _setStatus(CreatorDataStatus.error);
    }
  }

  /// Build booth-to-creators mapping
  Map<String, List<Creator>> _buildBoothMapping(List<Creator> creators) {
    final boothMap = <String, List<Creator>>{};
    for (final creator in creators) {
      for (final booth in creator.booths) {
        boothMap.putIfAbsent(booth, () => []).add(creator);
      }
    }
    return boothMap;
  }

  /// Build creator ID mapping
  Map<int, Creator> _buildCreatorIdMapping(List<Creator> creators) {
    final creatorMap = <int, Creator>{};
    for (final creator in creators) {
      creatorMap[creator.id] = creator;
    }
    return creatorMap;
  }

  /// Set creators and update booth mapping
  void _setCreators(List<Creator> creators) {
    _creators = creators;
    _boothToCreators = _buildBoothMapping(creators);
    _creatorById = _buildCreatorIdMapping(creators);

    if (isCreatorCustomListMode) {
      // Re-update the current creator list with the new creators
      setCreatorCustomList(_creatorCustomListIds!);
    }
    
    notifyListeners();
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error state
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  /// Set status
  void _setStatus(CreatorDataStatus status) {
    _status = status;
    notifyListeners();
  }

  /// Fetch creator data from remote server
  Future<List<Creator>?> _fetchRemoteCreatorData() async {
    try {
      // Add cache busting parameter
      final uri = Uri.parse(_dataUrl).replace(
        queryParameters: {
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        
        // Validate JSON structure
        if (!jsonData.containsKey('version') || !jsonData.containsKey('creators')) {
          print('Invalid creator data structure: missing version or creators field');
          return null;
        }

        final creatorsJson = jsonData['creators'] as List<dynamic>;
        
        // Parse creators
        final creators = creatorsJson.map((json) => Creator.fromJson(json)).toList();
        
        // Cache the data
        await _cacheCreatorData(jsonData);
        
        return creators;
      } else {
        print('Failed to fetch creator data: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching creator data: $e');
      return null;
    }
  }

  /// Get cached creator data from local storage
  Future<List<Creator>?> _getCachedCreatorData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDataString = prefs.getString(_cachedDataKey);
      
      if (cachedDataString == null) {
        return null;
      }

      final jsonData = json.decode(cachedDataString) as Map<String, dynamic>;
      
      // Validate JSON structure
      if (!jsonData.containsKey('version') || !jsonData.containsKey('creators')) {
        print('Invalid cached creator data structure: missing version or creators field');
        return null;
      }
      
      final creatorsJson = jsonData['creators'] as List<dynamic>;
      
      return creatorsJson.map((json) => Creator.fromJson(json)).toList();
    } catch (e) {
      print('Error loading cached creator data: $e');
      return null;
    }
  }

  /// Get cached data version
  Future<int?> _getCachedVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDataString = prefs.getString(_cachedDataKey);
      
      if (cachedDataString == null) {
        return null;
      }

      final jsonData = json.decode(cachedDataString) as Map<String, dynamic>;
      
      if (!jsonData.containsKey('version')) {
        print('Invalid cached creator data structure: missing version field');
        return null;
      }
      
      return jsonData['version'] as int;
    } catch (e) {
      print('Error loading cached version: $e');
      return null;
    }
  }

  /// Get bundled data version
  Future<int?> _getBundledVersion() async {
    try {
      final jsonString = await rootBundle.loadString('data/creator-data-initial.json');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      
      if (!jsonData.containsKey('version')) {
        print('Invalid bundled creator data structure: missing version field');
        return null;
      }
      
      return jsonData['version'] as int;
    } catch (e) {
      print('Error loading bundled version: $e');
      return null;
    }
  }

  /// Get current version from cached data (either from cache or bundled data)
  Future<int?> _getCurrentVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDataString = prefs.getString(_cachedDataKey);
      
      if (cachedDataString != null) {
        final jsonData = json.decode(cachedDataString) as Map<String, dynamic>;
        
        // Validate JSON structure
        if (!jsonData.containsKey('version')) {
          print('Invalid cached creator data structure: missing version field');
          return null;
        }
        
        return jsonData['version'] as int;
      }
      
      // If no cached data, check bundled data version
      final jsonString = await rootBundle.loadString('data/creator-data-initial.json');
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      
      if (!jsonData.containsKey('version')) {
        print('Invalid bundled creator data structure: missing version field');
        return null;
      }
      
      return jsonData['version'] as int;
    } catch (e) {
      print('Error loading current version: $e');
      return null;
    }
  }

  /// Cache creator data to local storage
  Future<void> _cacheCreatorData(Map<String, dynamic> jsonData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedDataKey, json.encode(jsonData));
    } catch (e) {
      print('Error caching creator data: $e');
    }
  }

  /// Check if remote version is newer than current version
  Future<bool> _isRemoteVersionNewer(int remoteVersion) async {
    final currentVersion = await _getCurrentVersion();
    return currentVersion == null || remoteVersion > currentVersion;
  }

  /// Check if we have valid cached data available
  Future<bool> hasCachedData() async {
    try {
      final cachedCreators = await _getCachedCreatorData();
      return cachedCreators != null && cachedCreators.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Clear cached data (useful for debugging or reset)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedDataKey);
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  /// Get creator by ID
  Creator? getCreatorById(int id) {
    return _creatorById?[id];
  }

  // Static methods for backward compatibility during transition
  static Future<List<Creator>?> fetchRemoteCreatorData() async {
    try {
      final provider = CreatorDataProvider();
      return await provider._fetchRemoteCreatorData();
    } catch (e) {
      print('Error fetching remote creator data: $e');
      return null;
    }
  }

  static Future<List<Creator>?> getCachedCreatorData() async {
    try {
      final provider = CreatorDataProvider();
      return await provider._getCachedCreatorData();
    } catch (e) {
      print('Error getting cached creator data: $e');
      return null;
    }
  }

  static Future<int?> getCurrentVersion() async {
    try {
      final provider = CreatorDataProvider();
      return await provider._getCurrentVersion();
    } catch (e) {
      print('Error getting current version: $e');
      return null;
    }
  }

  static Future<bool> isRemoteVersionNewer(int remoteVersion) async {
    try {
      final provider = CreatorDataProvider();
      return await provider._isRemoteVersionNewer(remoteVersion);
    } catch (e) {
      print('Error checking remote version: $e');
      return false;
    }
  }

  static Future<bool> hasCachedDataStatic() async {
    try {
      final provider = CreatorDataProvider();
      return await provider.hasCachedData();
    } catch (e) {
      return false;
    }
  }

  static Future<void> clearCacheStatic() async {
    try {
      final provider = CreatorDataProvider();
      await provider.clearCache();
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}