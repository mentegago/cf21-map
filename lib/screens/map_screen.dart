import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../services/map_parser.dart';
import '../services/version_service.dart';
import '../services/creator_data_service.dart';
import '../widgets/map_viewer.dart';
import '../widgets/mobile/creator_detail_sheet.dart';
import '../widgets/mobile/expandable_search.dart';
import '../widgets/mobile/creator_selector_sheet.dart';
import '../widgets/desktop/desktop_sidebar.dart';
import '../widgets/github_button.dart';
import '../widgets/version_notification.dart';
import '../models/map_cell.dart';
import '../models/creator.dart';
import 'dart:async';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  List<MergedCell>? _mergedCells;
  List<Creator>? _creators;
  Map<String, List<Creator>>? _boothToCreators;
  int _rows = 0;
  int _cols = 0;
  bool _isLoading = true;
  String? _error;
  List<String>? _highlightedBooths;
  Creator? _selectedCreator;
  late AnimationController _detailAnimationController;
  late Animation<Offset> _detailSlideAnimation;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _detailAnimationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _detailSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _detailAnimationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _loadData();
    _startPeriodicUpdateCheck();
  }

  @override
  void dispose() {
    _detailAnimationController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final startTime = DateTime.now();
      
      // Load map and creator data in parallel
      final results = await Future.wait([
        MapParser.loadMapData(),
        MapParser.loadCreatorData(),
      ]);
      
      final grid = results[0] as List<List<String>>;
      final creators = results[1] as List<Creator>;
      
      print('Data loaded in ${DateTime.now().difference(startTime).inMilliseconds}ms');
      
      final mergeStart = DateTime.now();
      final merged = MapParser.mergeCells(grid);
      print('Cells merged in ${DateTime.now().difference(mergeStart).inMilliseconds}ms');
      print('Total cells: ${grid.length * (grid.isEmpty ? 0 : grid[0].length)}');
      print('Merged to: ${merged.length} cells');
      print('Creators loaded: ${creators.length}');
      
      // Build booth-to-creators mapping
      final boothMap = <String, List<Creator>>{};
      for (final creator in creators) {
        for (final booth in creator.booths) {
          boothMap.putIfAbsent(booth, () => []).add(creator);
        }
      }
      
      setState(() {
        _mergedCells = merged;
        _creators = creators;
        _boothToCreators = boothMap;
        _rows = grid.length;
        _cols = grid.isEmpty ? 0 : grid[0].length;
        _isLoading = false;
      });
      
      // Handle query parameter if booth is specified in URL
      _handleQueryParameters();
      
      // Check for creator data updates after initial load
      _checkAndUpdateCreatorData();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _handleCreatorSelected(Creator creator, {bool fromSearch = true}) {
    setState(() {
      _selectedCreator = creator;
      _highlightedBooths = creator.booths;
    });
    _detailAnimationController.forward();
  }

  void _clearSelection() async {
    await _detailAnimationController.reverse();
    setState(() {
      _selectedCreator = null;
      _highlightedBooths = null;
    });
  }

  void _handleBoothTap(String? boothId) {
    if (boothId == null || _boothToCreators == null) return;
    
    final creators = _boothToCreators![boothId];
    if (creators == null || creators.isEmpty) return;
    
    if (creators.length == 1) {
      // Only one creator - show detail immediately (don't center)
      _handleCreatorSelected(creators.first, fromSearch: false);
    } else {
      // Multiple creators - show selector
      showModalBottomSheet(
        context: context,
        builder: (context) => CreatorSelectorSheet(
          boothId: boothId,
          creators: creators,
          onCreatorSelected: (creator) => _handleCreatorSelected(creator, fromSearch: false),
        ),
      );
    }
  }

  void _handleQueryParameters() {
    try {
      final uri = Uri.parse(html.window.location.href);
      final creatorParam = uri.queryParameters['creator'];
      
      if (creatorParam != null && creatorParam.isNotEmpty && _creators != null) {
        // Decode and normalize name (replace + with space, trim)
        final searchName = Uri.decodeComponent(creatorParam.replaceAll('+', ' ')).trim().toLowerCase();
        
        // Small delay to ensure UI is ready
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _creators != null) {
            // Find creator by name (case-insensitive, partial match)
            final creator = _creators!.firstWhere(
              (c) => c.name.toLowerCase().contains(searchName),
              orElse: () => _creators!.firstWhere(
                (c) => c.name.toLowerCase() == searchName,
                orElse: () => _creators!.first, // fallback, won't be used if null check below
              ),
            );
            
            // Only select if we found a match
            if (creator.name.toLowerCase().contains(searchName)) {
              _handleCreatorSelected(creator, fromSearch: true);
            }
          }
        });
      }
    } catch (e) {
      // Ignore errors in query parameter parsing
      print('Error parsing query parameters: $e');
    }
  }

  void _startPeriodicUpdateCheck() {
    // Check for updates every hour
    _updateTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _checkAndUpdateCreatorData();
    });
  }

  Future<void> _checkAndUpdateCreatorData() async {
    try {
      // Fetch version info
      final versionInfo = await VersionService.fetchVersionInfo();
      if (versionInfo == null) {
        return;
      }

      // Check if remote version is newer
      final isNewer = await CreatorDataService.isRemoteVersionNewer(versionInfo.creatorDataVersion);
      if (!isNewer) return;

      // Show updating snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Updating creator booth list'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Fetch new creator data
      final newCreators = await CreatorDataService.fetchRemoteCreatorData();
      if (newCreators == null || newCreators.isEmpty) {
        return;
      }

      // Sort creators by name
      final sortedCreators = List<Creator>.from(newCreators);
      sortedCreators.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // Check if current selection still exists
      Creator? preservedSelection;
      if (_selectedCreator != null) {
        try {
          preservedSelection = sortedCreators.firstWhere(
            (c) => c.id == _selectedCreator!.id,
          );
        } catch (e) {
          // Creator no longer exists, will clear selection
        }
      }

      // Build new booth mapping
      final boothMap = <String, List<Creator>>{};
      for (final creator in sortedCreators) {
        for (final booth in creator.booths) {
          boothMap.putIfAbsent(booth, () => []).add(creator);
        }
      }

      // Update state
      if (mounted) {
        setState(() {
          _creators = sortedCreators;
          _boothToCreators = boothMap;
          _selectedCreator = preservedSelection;
          _highlightedBooths = preservedSelection?.booths;
        });

        // Show updated snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Creator booth list updated'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error checking/updating creator data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 768; // Breakpoint for desktop layout

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Error loading map: $_error'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isLoading = true;
                              _error = null;
                            });
                            _loadData();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : isDesktop
                  ? _buildDesktopLayout()
                  : _buildMobileLayout(),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        if (_creators != null)
          DesktopSidebar(
            creators: _creators!,
            selectedCreator: _selectedCreator,
            onCreatorSelected: _handleCreatorSelected,
            onClear: _selectedCreator != null ? _clearSelection : null,
          ),
        
        // Map viewer
        Expanded(
          child: Stack(
            children: [
              MapViewer(
                mergedCells: _mergedCells!,
                rows: _rows,
                cols: _cols,
                highlightedBooths: _highlightedBooths,
                onBoothTap: _handleBoothTap,
              ),
              const GitHubButton(isDesktop: true),
              const VersionNotification(isDesktop: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Stack(
      children: [
        MapViewer(
          mergedCells: _mergedCells!,
          rows: _rows,
          cols: _cols,
          highlightedBooths: _highlightedBooths,
          onBoothTap: _handleBoothTap,
        ),
        
        const GitHubButton(isDesktop: false),
        const VersionNotification(isDesktop: false),
        
        if (_selectedCreator != null)
          SlideTransition(
            position: _detailSlideAnimation,
            child: CreatorDetailSheet(
              creator: _selectedCreator!,
              onClose: _clearSelection,
            ),
          ),

        if (_creators != null)
          ExpandableSearch(
            creators: _creators!,
            onCreatorSelected: _handleCreatorSelected,
            onClear: _selectedCreator != null ? _clearSelection : null,
            selectedCreator: _selectedCreator,
          ),
      ],
    );
  }
}

