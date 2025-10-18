import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CatalogService {
  // Firebase Cloud Function proxy URL
  static const String _catalogUrl = 'https://catalogproxy-wfte5uwlza-uc.a.run.app/catalog';

  // Cache configuration
  static const String _cacheKey = 'catalog_data';
  static const String _timestampKey = 'catalog_timestamp';
  static const Duration _cacheDuration = Duration(hours: 12);

  /// Fetches catalog data from the Firebase proxy which handles CORS and HTML parsing.
  static Future<Map<String, dynamic>?> fetchCatalogData() async {
    try {
      print('[CatalogService] Fetching catalog data from Firebase proxy: $_catalogUrl');

      final response = await http.get(
        Uri.parse(_catalogUrl),
        headers: {
          'User-Agent': 'CF21-Map-NNT/1.0.0',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 45)); // Slightly longer timeout for Firebase

      if (response.statusCode != 200) {
        print('[CatalogService] Failed to fetch from proxy: ${response.statusCode}');
        print('[CatalogService] Response: ${response.body}');
        return null;
      }

      print('[CatalogService] Received ${response.body.length} characters from proxy');

      // Parse the JSON response from Firebase
      final responseData = json.decode(response.body) as Map<String, dynamic>;

      // Check if the response indicates success
      if (responseData['success'] != true) {
        print('[CatalogService] Proxy returned error: ${responseData['error']}');
        return null;
      }

      // Extract the actual catalog data
      final catalogData = responseData['data'] as Map<String, dynamic>;
      print('[CatalogService] Successfully received catalog data with ${catalogData.length} top-level keys');

      // Log some statistics
      if (catalogData.containsKey('circle') && catalogData['circle'].containsKey('allCircle')) {
        final circles = catalogData['circle']['allCircle'] as List;
        print('[CatalogService] Catalog contains ${circles.length} circles');
      }

      return catalogData;

    } catch (e) {
      print('[CatalogService] Error fetching catalog data from proxy: $e');
      return null;
    }
  }

  /// Checks if cached data exists and is still valid (less than 12 hours old)
  static Future<bool> _isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_timestampKey);

      if (timestamp == null) {
        print('[CatalogService] No cached data found');
        return false;
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final age = now.difference(cacheTime);

      final isValid = age < _cacheDuration;
      print('[CatalogService] Cache age: ${age.inHours} hours, ${age.inMinutes % 60} minutes. Valid: $isValid');

      if (!isValid) {
        print('[CatalogService] Cache expired, will fetch fresh data');
      }

      return isValid;
    } catch (e) {
      print('[CatalogService] Error checking cache validity: $e');
      return false;
    }
  }

  /// Retrieves cached catalog data
  static Future<Map<String, dynamic>?> _getCachedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);

      if (cachedJson == null) {
        print('[CatalogService] No cached data available');
        return null;
      }

      final data = json.decode(cachedJson) as Map<String, dynamic>;
      print('[CatalogService] Retrieved cached data with ${data.length} top-level keys');

      return data;
    } catch (e) {
      print('[CatalogService] Error retrieving cached data: $e');
      return null;
    }
  }

  /// Stores catalog data in cache with current timestamp
  static Future<void> _cacheData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(data);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await prefs.setString(_cacheKey, jsonString);
      await prefs.setInt(_timestampKey, timestamp);

      print('[CatalogService] Cached ${jsonString.length} characters of data at timestamp $timestamp');
    } catch (e) {
      print('[CatalogService] Error caching data: $e');
    }
  }

  /// Gets catalog data with caching and error handling
  static Future<Map<String, dynamic>?> getCatalogData() async {
    print('[CatalogService] Requesting catalog data...');

    // Check if we have valid cached data
    if (await _isCacheValid()) {
      print('[CatalogService] Using cached data');
      return await _getCachedData();
    }

    // No valid cache, fetch fresh data
    print('[CatalogService] Fetching fresh data from API');
    final freshData = await fetchCatalogData();

    if (freshData != null) {
      await _cacheData(freshData);
      print('[CatalogService] Fresh data cached successfully');
    } else {
      print('[CatalogService] Failed to fetch fresh data, will try to use stale cache');
      // If fresh fetch failed, try to return stale cache as fallback
      return await _getCachedData();
    }

    return freshData;
  }

  /// Example: Get all circles from the catalog
  static Future<List<Map<String, dynamic>>?> getAllCircles() async {
    print('[CatalogService] Getting all circles...');
    final data = await getCatalogData();
    if (data == null) {
      print('[CatalogService] No catalog data available');
      return null;
    }

    final circleData = data['circle'] as Map<String, dynamic>?;
    if (circleData == null) {
      print('[CatalogService] No circle data found in catalog');
      return null;
    }

    final allCircles = circleData['allCircle'] as List<dynamic>?;
    if (allCircles == null) {
      print('[CatalogService] No allCircle array found');
      return null;
    }

    final circles = allCircles.whereType<Map<String, dynamic>>().toList();
    print('[CatalogService] Retrieved ${circles.length} circles');
    return circles;
  }

  /// Example: Search circles by name or code
  static Future<List<Map<String, dynamic>>?> searchCircles(String query) async {
    print('[CatalogService] Searching circles for: "$query"');
    final circles = await getAllCircles();
    if (circles == null) return null;

    final lowerQuery = query.toLowerCase();
    final results = circles.where((circle) {
      final name = (circle['name'] as String?)?.toLowerCase() ?? '';
      final code = (circle['circle_code'] as String?)?.toLowerCase() ?? '';
      return name.contains(lowerQuery) || code.contains(lowerQuery);
    }).toList();

    print('[CatalogService] Found ${results.length} circles matching "$query"');
    return results;
  }

  /// Clears all cached catalog data (useful for debugging or forcing refresh)
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_timestampKey);
      print('[CatalogService] Cache cleared successfully');
    } catch (e) {
      print('[CatalogService] Error clearing cache: $e');
    }
  }

  /// Gets cache information for debugging
  static Future<Map<String, dynamic>> getCacheInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_timestampKey);
      final hasData = prefs.containsKey(_cacheKey);

      final info = {
        'hasData': hasData,
        'timestamp': timestamp,
        'cacheAge': timestamp != null
            ? DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp))
            : null,
        'isValid': timestamp != null
            ? DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp)) < _cacheDuration
            : false,
      };

      print('[CatalogService] Cache info: $info');
      return info;
    } catch (e) {
      print('[CatalogService] Error getting cache info: $e');
      return {'error': e.toString()};
    }
  }
}
