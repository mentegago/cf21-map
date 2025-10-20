import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _useCardViewKey = 'use_card_view';
  static SharedPreferences? _prefs;

  // Local state for fast synchronous access
  bool _useCardView = false;
  
  // Debounce timer for storage updates
  Timer? _storageUpdateTimer;
  static const Duration _debounceDelay = Duration(milliseconds: 500);

  // Synchronous getter for UI
  bool get useCardView => _useCardView;

  // Synchronous setter for UI
  void setUseCardView(bool value) {
    if (_useCardView != value) {
      _useCardView = value;
      notifyListeners();
      _scheduleStorageUpdate();
    }
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
      await _prefs!.setBool(_useCardViewKey, _useCardView);
    } catch (e) {
      if (kDebugMode) {
        print('Failed to save settings: $e');
      }
    }
  }

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

  /// Initialize and load settings from storage
  Future<void> initialize() async {
    await _initPrefs();
    
    if (_prefs != null) {
      _useCardView = _prefs!.getBool(_useCardViewKey) ?? false;
    }
    
    if (kDebugMode) {
      print('SettingsProvider: ${_prefs == null ? 'Storage not available' : 'Storage available'}, loaded useCardView: $_useCardView');
    }

    _scheduleStorageUpdate();
  }

  @override
  void dispose() {
    _storageUpdateTimer?.cancel();
    super.dispose();
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
}