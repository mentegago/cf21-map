import 'package:cf21_map_flutter/services/creator_data_service.dart';
import 'package:cf21_map_flutter/services/favorites_service.dart';
import 'package:cf21_map_flutter/widgets/creator_tile.dart';
import 'package:cf21_map_flutter/widgets/creator_tile_featured.dart';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/creator.dart';

class CreatorListView extends StatefulWidget {
  final List<Creator> creators;
  final String searchQuery;
  final Function(Creator) onCreatorSelected;
  final ScrollController? scrollController;

  const CreatorListView({
    super.key,
    required this.creators,
    required this.searchQuery,
    required this.onCreatorSelected,
    this.scrollController
  });

  @override
  State<CreatorListView> createState() => _CreatorListViewState();
}

class _CreatorListViewState extends State<CreatorListView> {
  List<Creator>? _cachedFilteredCreators;
  String? _lastSearchQuery;
  
  List<Creator> get _filteredCreators {
    // Return cached results if search query hasn't changed
    if (_lastSearchQuery == widget.searchQuery && _cachedFilteredCreators != null) {
      return _cachedFilteredCreators!;
    }
    
    // Update cache
    _lastSearchQuery = widget.searchQuery;
    
    if (widget.searchQuery.isEmpty) {
      _cachedFilteredCreators = widget.creators;
      return _cachedFilteredCreators!;
    }
    
    final lowerQuery = widget.searchQuery.toLowerCase();
    final filteredBoothQuery = _filterBoothFormat(lowerQuery);
    
    _cachedFilteredCreators = widget.creators.where((creator) {
      // Name matching
      if (creator.name.toLowerCase().contains(lowerQuery)) {
        return true;
      }

      // Booth matching
      for (final booth in creator.booths) {
        if (_filterBoothFormat(booth).startsWith(filteredBoothQuery)) {
          return true;
        }
      }

      // Fandom matching
      for (final fandom in creator.fandoms) {
        if (fandom.toLowerCase().contains(lowerQuery)) {
          return true;
        }
      }

      return false;
    }).toList();
    
    return _cachedFilteredCreators!;
  }

  String _filterBoothFormat(String query) {
    // Remove non-alphanumeric chars, make lower, and drop zeroes after letters (e.g. "AB08" => "ab8")
    return query
      .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
      .replaceAllMapped(
        RegExp(r'([a-zA-Z])0+'), 
        (m) => m.group(1) ?? ''
      )
      .toLowerCase();
  }

  @override
  void didUpdateWidget(CreatorListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If creators list has changed, clear cache and trigger rebuild
    if (oldWidget.creators != widget.creators) {
      _cachedFilteredCreators = null;
      _lastSearchQuery = null;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.searchQuery.isNotEmpty) {
      return _buildSearchResults(context);
    } else {
      return _buildMainView(context);
    }
  }

  Widget _buildSearchResults(BuildContext context) {
    final theme = Theme.of(context);
    final itemCount = _filteredCreators.isEmpty 
      ? 2 // results count header + no results message
      : _filteredCreators.length + 1; // +1 for results count header
    
    return ListView.builder(
      controller: widget.scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Results count header
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '${_filteredCreators.length} result${_filteredCreators.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          );
        }
        
        if (_filteredCreators.isEmpty) {
          // No results message
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No results found',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // Regular search result
        final creator = _filteredCreators[index - 1];
        return CreatorTile(creator: creator, onCreatorSelected: widget.onCreatorSelected);
      },
    );
  }

  Widget _buildMainView(BuildContext context) {
    final theme = Theme.of(context);
    final isCreatorCustomListMode = context.select((CreatorDataProvider creatorDataProvider) => creatorDataProvider.isCreatorCustomListMode);

    final List<Creator> favorites = isCreatorCustomListMode ? [] : context.select((FavoritesService favoritesService) => favoritesService.favorites);
    // Calculate total item count for ListView.builder
    int itemCount = 0;
    
    // Featured section: header + featured creator
    itemCount += 2;
    
    // Favorites section: header + favorites (if any and storage is available)
    if (favorites.isNotEmpty) {
      itemCount += 1 + favorites.length;
    }
    
    // All creators section: header + all creators
    itemCount += 1 + _filteredCreators.length;

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return _buildItemAtIndex(index, theme, favorites, isCreatorCustomListMode);
      },
    );
  }

  Widget _buildItemAtIndex(int index, ThemeData theme, List<Creator> favorites, bool isCreatorCustomListMode) {
    int currentIndex = 0;
    
    // Featured section
    if (index == 0) {
      if (isCreatorCustomListMode) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.group, size: 19),
            label: const Text(
              'See All Creators',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                letterSpacing: 0.1,
              ),
            ),
            onPressed: () {
              final provider = context.read<CreatorDataProvider>();
              provider.clearCreatorCustomList();
            },
          ),
        );
      }
      else {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Check us out~',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
        );
      }
    }
    currentIndex++;
    
    if (index == 1) {
      if (isCreatorCustomListMode) {
        return const SizedBox.shrink();
      }
      
      final featuredCreator = widget.creators.firstWhereOrNull(
        (c) => c.id == 5450
      );
      return featuredCreator != null 
        ? CreatorTileFeatured(creator: featuredCreator, onCreatorSelected: widget.onCreatorSelected) 
        : const SizedBox.shrink();
    }
    currentIndex++;
    
    // Favorites section
    if (favorites.isNotEmpty) {
      if (index == 2) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Favorites',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
        );
      }
      currentIndex++;
      
      final favoriteIndex = index - 3;
      if (favoriteIndex >= 0 && favoriteIndex < favorites.length) {
        return CreatorTile(creator: favorites[favoriteIndex], onCreatorSelected: widget.onCreatorSelected);
      }
      currentIndex += favorites.length;
    }
    
    // All creators section
    if (index == currentIndex) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          isCreatorCustomListMode ? 'Custom Creator List' : 'All Creators',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            letterSpacing: 0.5,
          ),
        ),
      );
    }
    currentIndex++;
    
    // All creators items
    final creatorIndex = index - currentIndex;
    if (creatorIndex >= 0 && creatorIndex < _filteredCreators.length) {
      return CreatorTile(creator: _filteredCreators[creatorIndex], onCreatorSelected: widget.onCreatorSelected);
    }
    
    return const SizedBox.shrink();
  }
}
