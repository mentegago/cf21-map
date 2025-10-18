import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/creator.dart';

class CreatorDataService {
  static const String _dataUrl = 'https://cf21-config.nnt.gg/data/creator-data.json';
  static const String _cachedDataKey = 'cached_creator_data';

  /// Fetch creator data from remote server
  static Future<List<Creator>?> fetchRemoteCreatorData() async {
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
  static Future<List<Creator>?> getCachedCreatorData() async {
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

  /// Get cached version number from the cached JSON data
  static Future<int?> getCachedVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedDataString = prefs.getString(_cachedDataKey);
      
      if (cachedDataString == null) {
        return null;
      }

      final jsonData = json.decode(cachedDataString) as Map<String, dynamic>;
      
      // Validate JSON structure
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

  /// Cache creator data to local storage
  static Future<void> _cacheCreatorData(Map<String, dynamic> jsonData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cachedDataKey, json.encode(jsonData));
    } catch (e) {
      print('Error caching creator data: $e');
    }
  }

  /// Check if remote version is newer than cached version
  static Future<bool> isRemoteVersionNewer(int remoteVersion) async {
    final cachedVersion = await getCachedVersion();
    return cachedVersion == null || remoteVersion > cachedVersion;
  }

  /// Check if we have valid cached data available
  static Future<bool> hasCachedData() async {
    try {
      final cachedCreators = await getCachedCreatorData();
      return cachedCreators != null && cachedCreators.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Clear cached data (useful for debugging or reset)
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedDataKey);
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}
