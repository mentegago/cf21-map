import 'package:cf21_map_flutter/services/favorites_service.dart';
import 'package:cf21_map_flutter/widgets/creator_tile.dart';
import 'package:cf21_map_flutter/widgets/creator_tile_featured.dart';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/creator.dart';
import '../services/creator_data_service.dart';

class CreatorListView extends StatefulWidget {
  final List<Creator> creators;
  final List<Creator> filteredCreators;
  final bool hasSearched;
  final Function(Creator) onCreatorSelected;
  final ScrollController? scrollController;

  const CreatorListView({
    super.key,
    required this.creators,
    required this.filteredCreators,
    required this.hasSearched,
    required this.onCreatorSelected,
    this.scrollController
  });

  @override
  State<CreatorListView> createState() => _CreatorListViewState();
}

class _CreatorListViewState extends State<CreatorListView> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hasSearched) {
      return _buildSearchResults(context);
    } else {
      return _buildMainView(context);
    }
  }

  Widget _buildSearchResults(BuildContext context) {
    final theme = Theme.of(context);
    final itemCount = widget.filteredCreators.isEmpty 
      ? 2 // results count header + no results message
      : widget.filteredCreators.length + 1; // +1 for results count header
    
    return ListView.builder(
      controller: widget.scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Results count header
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '${widget.filteredCreators.length} result${widget.filteredCreators.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          );
        }
        
        if (widget.filteredCreators.isEmpty) {
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
        final creator = widget.filteredCreators[index - 1];
        return CreatorTile(creator: creator, onCreatorSelected: widget.onCreatorSelected);
      },
    );
  }

  Widget _buildMainView(BuildContext context) {
    final theme = Theme.of(context);
    final favorites = context.select((FavoritesService favoritesService) => favoritesService.favorites);
    // Calculate total item count for ListView.builder
    int itemCount = 0;
    
    // Featured section: header + featured creator
    itemCount += 2;
    
    // Favorites section: header + favorites (if any and storage is available)
    if (favorites.isNotEmpty) {
      itemCount += 1 + favorites.length;
    }
    
    // All creators section: header + all creators
    itemCount += 1 + widget.filteredCreators.length;

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return _buildItemAtIndex(index, theme, favorites);
      },
    );
  }

  Widget _buildItemAtIndex(int index, ThemeData theme, List<Creator> favorites) {
    int currentIndex = 0;
    
    // Featured section
    if (index == 0) {
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
    currentIndex++;
    
    if (index == 1) {
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
          'All Creators',
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
    if (creatorIndex >= 0 && creatorIndex < widget.filteredCreators.length) {
      return CreatorTile(creator: widget.filteredCreators[creatorIndex], onCreatorSelected: widget.onCreatorSelected);
    }
    
    return const SizedBox.shrink();
  }
}
