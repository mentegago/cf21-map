import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/creator.dart';
import 'catalog_service.dart';

class DataSourceManager extends ChangeNotifier {
  static const String _preferredDataSourceKey = 'preferred_data_source';

  DataSource _preferredDataSource = DataSource.catalog;
  List<Creator> _localCreators = [];
  List<Creator> _catalogCreators = [];
  bool _isLoading = true;
  String? _error;

  DataSource get preferredDataSource => _preferredDataSource;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get all creators based on preferred data source with fallback
  List<Creator> get allCreators {
    if (_preferredDataSource == DataSource.catalog) {
      // Catalog first, then local as fallback
      return _getCombinedCreators();
    } else {
      // Local only
      return _localCreators;
    }
  }

  // Get creators by data source
  List<Creator> getCreatorsBySource(DataSource source) {
    switch (source) {
      case DataSource.catalog:
        return _catalogCreators;
      case DataSource.local:
        return _localCreators;
    }
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load preferred data source
      await _loadPreferredDataSource();

      // Load local data
      await _loadLocalData();

      // Load catalog data
      await _loadCatalogData();

      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('DataSourceManager initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setPreferredDataSource(DataSource source) async {
    if (_preferredDataSource == source) return;

    _preferredDataSource = source;
    await _savePreferredDataSource();
    notifyListeners();
  }

  Future<void> refreshData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadCatalogData();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Creator> _getCombinedCreators() {
    final combined = <Creator>[];
    final catalogMap = {for (final creator in _catalogCreators) creator.name: creator};
    final localMap = {for (final creator in _localCreators) creator.name: creator};

    // Add all catalog creators
    combined.addAll(_catalogCreators);

    // Add local creators that don't exist in catalog
    for (final localCreator in _localCreators) {
      if (!catalogMap.containsKey(localCreator.name)) {
        combined.add(localCreator);
      }
    }

    return combined;
  }

  Future<void> _loadPreferredDataSource() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedSource = prefs.getString(_preferredDataSourceKey);
      if (savedSource != null) {
        _preferredDataSource = DataSource.values.firstWhere(
          (source) => source.name == savedSource,
          orElse: () => DataSource.catalog,
        );
      }
    } catch (e) {
      debugPrint('Error loading preferred data source: $e');
    }
  }

  Future<void> _savePreferredDataSource() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_preferredDataSourceKey, _preferredDataSource.name);
    } catch (e) {
      debugPrint('Error saving preferred data source: $e');
    }
  }

  Future<void> _loadLocalData() async {
    try {
      final jsonString = await rootBundle.loadString('data/creator-data.json');
      final jsonData = json.decode(jsonString) as List<dynamic>;

      _localCreators = jsonData
          .whereType<Map<String, dynamic>>()
          .map((json) => Creator.fromJson(json, dataSource: DataSource.local))
          .toList();

      debugPrint('Loaded ${_localCreators.length} local creators');
    } catch (e) {
      debugPrint('Error loading local data: $e');
      _localCreators = [];
    }
  }

  Future<void> _loadCatalogData() async {
    try {
      final circles = await CatalogService.getAllCircles();

      if (circles != null) {
        _catalogCreators = circles
            .map((circleJson) => Creator.fromJson(circleJson, dataSource: DataSource.catalog))
            .toList();

        debugPrint('Loaded ${_catalogCreators.length} catalog creators');
      } else {
        _catalogCreators = [];
        debugPrint('No catalog data available');
      }
    } catch (e) {
      debugPrint('Error loading catalog data: $e');
      _catalogCreators = [];
    }
  }

  // Helper method to find creator by booth code
  Creator? findCreatorByBooth(String boothCode) {
    try {
      return allCreators.firstWhere(
        (creator) => creator.booths.contains(boothCode),
      );
    } catch (e) {
      return null;
    }
  }

  // Helper method to find creator by name
  Creator? findCreatorByName(String name) {
    try {
      return allCreators.firstWhere(
        (creator) => creator.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // Get statistics
  Map<String, int> getStatistics() {
    return {
      'totalLocal': _localCreators.length,
      'totalCatalog': _catalogCreators.length,
      'totalCombined': allCreators.length,
      'missingInCatalog': _localCreators.where((local) {
        return !_catalogCreators.any((catalog) => catalog.name == local.name);
      }).length,
    };
  }
}
