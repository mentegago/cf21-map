import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html;
import '../services/map_parser.dart';
import '../services/data_source_manager.dart';
import '../widgets/map_viewer.dart';
import '../widgets/mobile/creator_detail_sheet.dart';
import '../widgets/mobile/expandable_search.dart';
import '../widgets/mobile/creator_selector_sheet.dart';
import '../widgets/desktop/desktop_sidebar.dart';
import '../widgets/github_button.dart';
import '../widgets/version_notification.dart';
import '../widgets/data_source_toggle.dart';
import '../models/map_cell.dart';
import '../models/creator.dart';

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

    // Load data after the first frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      // Listen to data source changes
      context.read<DataSourceManager>().addListener(_onDataSourceChanged);
    });
  }

  @override
  void dispose() {
    // Remove listener
    if (mounted) {
      context.read<DataSourceManager>().removeListener(_onDataSourceChanged);
    }
    _detailAnimationController.dispose();
    super.dispose();
  }

  void _onDataSourceChanged() {
    // Reload data when data source changes
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final startTime = DateTime.now();

      // Get data source manager
      final dataSourceManager = context.read<DataSourceManager>();

      // Load map data
      final grid = await MapParser.loadMapData();

      // Get creators from data source manager (already loaded in main.dart)
      final creators = dataSourceManager.allCreators;

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
    print('\n=== BOOTH CLICK DEBUG ===');
    print('[BoothClick] User clicked on booth: "$boothId"');

    if (boothId == null) {
      print('[BoothClick] ERROR: Booth ID is null');
      return;
    }

    if (_boothToCreators == null) {
      print('[BoothClick] ERROR: Booth-to-creators mapping not initialized');
      return;
    }

    final creators = _boothToCreators![boothId];
    if (creators == null) {
      print('[BoothClick] No creators found for booth "$boothId"');
      print('[BoothClick] Available booth mappings (first 10): ${_boothToCreators!.keys.take(10).join(", ")}...');

      // Output full booth mappings as JSON for debugging
      print('[BoothClick] === FULL BOOTH MAPPINGS JSON ===');
      final mappingsJson = <String, dynamic>{};
      _boothToCreators!.forEach((boothId, creators) {
        mappingsJson[boothId] = creators.map((creator) => {
          'name': creator.name,
          'dataSource': creator.dataSource.name,
          'booths': creator.booths,
          'day': creator.day,
          'fandom': creator.fandom,
          'circleType': creator.circleType,
        }).toList();
      });

      // Pretty print the JSON
      const encoder = JsonEncoder.withIndent('  ');
      print(encoder.convert(mappingsJson));
      print('[BoothClick] === END FULL BOOTH MAPPINGS JSON ===');

      return;
    }

    if (creators.isEmpty) {
      print('[BoothClick] Empty creator list for booth "$boothId"');
      return;
    }

    print('[BoothClick] Found ${creators.length} creator(s) for booth "$boothId":');

    for (int i = 0; i < creators.length; i++) {
      final creator = creators[i];
      print('[BoothClick]   ${i + 1}. "${creator.name}" (${creator.dataSource.shortName})');
      print('[BoothClick]      Booths: [${creator.booths.join(", ")}]');
      print('[BoothClick]      Day: ${creator.day}');
      if (creator.fandom != null) {
        print('[BoothClick]      Fandom: ${creator.fandom}');
      }
      if (creator.circleType != null) {
        print('[BoothClick]      Type: ${creator.circleType}');
      }
    }

    if (creators.length == 1) {
      print('[BoothClick] Showing single creator detail sheet');
      // Only one creator - show detail immediately (don't center)
      _handleCreatorSelected(creators.first, fromSearch: false);
    } else {
      print('[BoothClick] Showing multi-creator selector sheet');
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

    print('[BoothClick] === END BOOTH CLICK DEBUG ===\n');
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
              const Positioned(
                top: 16,
                right: 16,
                child: DataSourceToggle(),
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

        // Data source toggle for mobile
        const Positioned(
          bottom: 16,
          right: 16,
          child: DataSourceToggle(),
        ),

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

