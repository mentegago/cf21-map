import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:html' as html;
import '../services/map_parser.dart';
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
  int _rows = 0;
  int _cols = 0;
  bool _isLoading = true;
  String? _error;
  late AnimationController _detailAnimationController;
  late Animation<Offset> _detailSlideAnimation;
  final GlobalKey<ExpandableSearchState> _expandableSearchKey = GlobalKey<ExpandableSearchState>();

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
    _loadMapData();
  }

  @override
  void dispose() {
    _detailAnimationController.dispose();
    super.dispose();
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

  void _handleCreatorSelected(Creator creator, {bool fromSearch = true}) {
    final creatorProvider = context.read<CreatorDataProvider>();
    creatorProvider.setSelectedCreator(creator);
    _detailAnimationController.forward();
  }

  void _clearSelection() async {
    final creatorProvider = context.read<CreatorDataProvider>();
    await _detailAnimationController.reverse();
    if (mounted) {
      creatorProvider.setSelectedCreator(null);
    }
  }

  void _handleBoothTap(String? boothId) {
    if (boothId == null) return;
    
    final creatorProvider = context.read<CreatorDataProvider>();
    final boothToCreators = creatorProvider.boothToCreators;
    if (boothToCreators == null) return;
    
    final creators = boothToCreators[boothId];
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
      final creatorIdParam = int.tryParse(uri.queryParameters['creator_id'] ?? '');
      
      if (creatorIdParam != null) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          final creatorProvider = context.read<CreatorDataProvider>();
          final creator = creatorProvider.getCreatorById(creatorIdParam);
          print('creator: ${creator?.name ?? 'null'}');
          if (creator != null) {
            _handleCreatorSelected(creator, fromSearch: true);
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
                _handleCreatorSelected(creator, fromSearch: true);
              }
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
                : isDesktop
                    ? _buildDesktopLayout(context)
                    : _buildMobileLayout(context),
          // Clean snackbar listener
          _StatusSnackbarListener(),
        ],
      )
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final creators = context.select((CreatorDataProvider creatorProvider) => creatorProvider.creators);
    final selectedCreator = context.select((CreatorDataProvider creatorProvider) => creatorProvider.selectedCreator);

    return Row(
      children: [
        if (creators != null)
          DesktopSidebar(
            creators: creators,
            selectedCreator: selectedCreator,
            onCreatorSelected: _handleCreatorSelected,
            onClear: selectedCreator != null ? _clearSelection : null,
          ),
        
        // Map viewer
        Expanded(
          child: Stack(
            children: [
              MapViewer(
                mergedCells: _mergedCells!,
                rows: _rows,
                cols: _cols,
                highlightedBooths: selectedCreator?.booths,
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

  Widget _buildMobileLayout(BuildContext context) {
    final creators = context.select((CreatorDataProvider creatorProvider) => creatorProvider.creators);
    final selectedCreator = context.select((CreatorDataProvider creatorProvider) => creatorProvider.selectedCreator); 

    return Stack(
      children: [
        MapViewer(
          mergedCells: _mergedCells!,
          rows: _rows,
          cols: _cols,
          highlightedBooths: selectedCreator?.booths,
          onBoothTap: _handleBoothTap,
        ),
        
        const GitHubButton(isDesktop: false),
        const VersionNotification(isDesktop: false),
        
        if (selectedCreator != null)
          SlideTransition(
            position: _detailSlideAnimation,
            child: CreatorDetailSheet(
              creator: selectedCreator,
              onClose: _clearSelection,
              onRequestSearch: _handleMobileRequestSearch,
            ),
          ),

        if (creators != null)
          ExpandableSearch(
            key: _expandableSearchKey,
            creators: creators,
            onCreatorSelected: _handleCreatorSelected,
            onClear: selectedCreator != null ? _clearSelection : null,
            selectedCreator: selectedCreator,
          ),
      ],
    );
  }

  void _handleMobileRequestSearch(String query) {
    _expandableSearchKey.currentState?.performSearch(query);
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
              if (provider.status == CreatorDataStatus.updating) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Updating creator booth list'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } else if (provider.status == CreatorDataStatus.updated) {
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

