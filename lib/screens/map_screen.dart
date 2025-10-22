import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html;
import '../services/map_parser.dart';
import '../services/creator_data_service.dart';
import '../utils/int_encoding.dart';
import '../widgets/mobile/creator_selector_sheet.dart';
import '../models/map_cell.dart';
import '../models/creator.dart';
import 'map_screen_desktop.dart';
import 'map_screen_mobile.dart';
import 'dart:async';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<MergedCell>? _mergedCells;
  int _rows = 0;
  int _cols = 0;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    try {
      final startTime = DateTime.now();
      
      // Load map data
      final grid = await MapParser.loadMapData();
      
      print('Map data loaded in ${DateTime.now().difference(startTime).inMilliseconds}ms');
      
      final mergeStart = DateTime.now();
      final merged = MapParser.mergeCells(grid);
      print('Cells merged in ${DateTime.now().difference(mergeStart).inMilliseconds}ms');
      print('Total cells: ${grid.length * (grid.isEmpty ? 0 : grid[0].length)}');
      print('Merged to: ${merged.length} cells');
      
      setState(() {
        _mergedCells = merged;
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

  void _handleCreatorSelected(Creator creator) {
    final creatorProvider = context.read<CreatorDataProvider>();
    creatorProvider.setSelectedCreator(creator);

    _updateQueryParametersIfNeeded(creator.id);
  }

  Future<void> _clearSelection() async {
    final creatorProvider = context.read<CreatorDataProvider>();
    if (creatorProvider.selectedCreator != null) {
      creatorProvider.setSelectedCreator(null);
    }
    _updateQueryParametersIfNeeded(null);
  }

  void _handleBoothTap(String? boothId) {
    if (boothId == null) return;
    
    final creatorProvider = context.read<CreatorDataProvider>();
    final isCreatorCustomListMode = creatorProvider.isCreatorCustomListMode;
    final boothToCreators = isCreatorCustomListMode ? creatorProvider.boothToCreatorCustomList : creatorProvider.boothToCreators;
    if (boothToCreators == null) return;
    
    final creators = boothToCreators[boothId];
    if (creators == null || creators.isEmpty) return;
    
    if (creators.length == 1) {
      // Only one creator - show detail immediately (don't center)
      _handleCreatorSelected(creators.first);
    } else {
      // Multiple creators - show selector
      showModalBottomSheet(
        context: context,
        builder: (context) => CreatorSelectorSheet(
          boothId: boothId,
          creators: creators,
          onCreatorSelected: (creator) => _handleCreatorSelected(creator),
        ),
      );
    }
  }

  void _updateQueryParametersIfNeeded(int? creatorId) {
    if (kIsWeb) {
      final uri = Uri.parse(html.window.location.href);
      final creatorParam = uri.queryParameters['creator'];
      final creatorIdParam = int.tryParse(uri.queryParameters['creator_id'] ?? '');
      
      if (creatorParam != null || creatorIdParam != null) {
        html.window.history.pushState(null, '', creatorId != null ? '/?creator_id=$creatorId' : '/');
      }
    }
  }

  void _handleQueryParameters() {
    context.read<CreatorDataProvider>().onCreatorDataServiceInitialized(() {
      try {
        final uri = Uri.parse(html.window.location.href);
        final creatorParam = uri.queryParameters['creator'];
        final creatorIdParam = int.tryParse(uri.queryParameters['creator_id'] ?? '');
        final compressedCreatorCustomListParam = uri.queryParameters['list'];
        final creatorCustomListParam = uri.queryParameters['custom_list'];

        if (compressedCreatorCustomListParam != null) {
          final creatorProvider = context.read<CreatorDataProvider>();
          final idList = IntEncoding.stringCodeToInts(compressedCreatorCustomListParam);

          if (idList.isNotEmpty) {
            creatorProvider.setCreatorCustomList(idList);
          }
        }

        if (creatorCustomListParam != null) {
          final creatorProvider = context.read<CreatorDataProvider>();
          final idStrings = creatorCustomListParam.split(',');
          final idList = idStrings
              .map((idStr) => int.tryParse(idStr.trim()))
              .where((id) => id != null)
              .cast<int>()
              .toList();
          

          if (idList.isNotEmpty) {
            creatorProvider.setCreatorCustomList(idList);
          }
        }
        
        if (creatorIdParam != null) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            final creatorProvider = context.read<CreatorDataProvider>();
            final creator = creatorProvider.getCreatorById(creatorIdParam);
            print('creator: ${creator?.name ?? 'null'}');
            if (creator != null) {
              _handleCreatorSelected(creator);
            }
          });
        } else if (creatorParam != null && creatorParam.isNotEmpty) {
          // Decode and normalize name (replace + with space, trim)
          final searchName = Uri.decodeComponent(creatorParam.replaceAll('+', ' ')).trim().toLowerCase();
          
          // Small delay to ensure UI is ready
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              final creatorProvider = context.read<CreatorDataProvider>();
              final creators = creatorProvider.creators;
              if (creators != null && creators.isNotEmpty) {
                // Find creator by name (case-insensitive, partial match)
                final creator = creators.firstWhere(
                  (c) => c.name.toLowerCase().contains(searchName),
                  orElse: () => creators.firstWhere(
                    (c) => c.name.toLowerCase() == searchName,
                    orElse: () => creators.first, // fallback, won't be used if null check below
                  ),
                );
                
                // Only select if we found a match
                if (creator.name.toLowerCase().contains(searchName)) {
                  _handleCreatorSelected(creator);
                }
              }
            }
          });
        }
      } catch (e) {
        print('Error parsing query parameters: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select((CreatorDataProvider creatorProvider) => creatorProvider.isLoading);
    final error = context.select((CreatorDataProvider creatorProvider) => creatorProvider.error);
    
    return Scaffold(
      body: Stack(
        children: [
          _isLoading || isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null || error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text('Error loading map: ${_error ?? error}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _error = null;
                              });
                              _loadMapData();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _isDesktop
                    ? _buildDesktopLayout(context)
                    : _buildMobileLayout(context),
          // Clean snackbar listener
          _StatusSnackbarListener(),
        ],
      )
    );
  }

  bool get _isDesktop {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth > 768; // Breakpoint for desktop layout
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return MapScreenDesktopView(
      mergedCells: _mergedCells!,
      rows: _rows,
      cols: _cols,
      onCreatorSelected: _handleCreatorSelected,
      onClearSelection: _clearSelection,
      onBoothTap: _handleBoothTap,
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return MapScreenMobileView(
      mergedCells: _mergedCells!,
      rows: _rows,
      cols: _cols,
      onClearSelection: _clearSelection,
      onCreatorSelected: _handleCreatorSelected,
      onBoothTap: _handleBoothTap,
    );
  }
}

class _StatusSnackbarListener extends StatefulWidget {
  @override
  _StatusSnackbarListenerState createState() => _StatusSnackbarListenerState();
}

class _StatusSnackbarListenerState extends State<_StatusSnackbarListener> {
  CreatorDataStatus? _previousStatus;

  @override
  Widget build(BuildContext context) {
    return Consumer<CreatorDataProvider>(
      builder: (context, provider, child) {
        // Only show snackbar when status actually changes
        if (_previousStatus != provider.status) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (provider.status == CreatorDataStatus.updated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Creator booth list updated'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
          });
          _previousStatus = provider.status;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

