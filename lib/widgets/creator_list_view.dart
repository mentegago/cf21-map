import 'package:cf21_map_flutter/services/favorites_service.dart';
import 'package:cf21_map_flutter/widgets/creator_tile.dart';
import 'package:cf21_map_flutter/widgets/creator_tile_featured.dart';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import '../models/creator.dart';

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
  final _favoritesService = FavoritesService.instance;
  late final _featuredCreator = widget.creators.firstWhereOrNull(
    (c) => c.name.toLowerCase().contains('negi no tomodachi')
  );
  
  List<Creator>? _favorites;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (!widget.hasSearched) {
      final favorites = await _favoritesService.getFavorites();
      if (mounted) {
        setState(() {
          _favorites = favorites;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedBuilder(
      animation: _favoritesService,
      builder: (context, child) {
        _loadFavorites();
        
        if (widget.hasSearched) {
          return _buildSearchResults(theme);
        } else {
          return _buildMainView(theme);
        }
      },
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
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

  Widget _buildMainView(ThemeData theme) {
    // Calculate total item count for ListView.builder
    int itemCount = 0;
    
    // Featured section: header + featured creator
    itemCount += 2;
    
    // Favorites section: header + favorites (if any and storage is available)
    if (_favoritesService.isStorageAvailable && (_favorites?.isNotEmpty ?? false)) {
      itemCount += 1 + (_favorites!.length);
    }
    
    // All creators section: header + all creators
    itemCount += 1 + widget.filteredCreators.length;

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return _buildItemAtIndex(index, theme);
      },
    );
  }

  Widget _buildItemAtIndex(int index, ThemeData theme) {
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
      return _featuredCreator != null 
        ? CreatorTileFeatured(creator: _featuredCreator!, onCreatorSelected: widget.onCreatorSelected) 
        : const SizedBox.shrink();
    }
    currentIndex++;
    
    // Favorites section
    if (_favoritesService.isStorageAvailable && (_favorites?.isNotEmpty ?? false)) {
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
      if (favoriteIndex >= 0 && favoriteIndex < _favorites!.length) {
        return CreatorTile(creator: _favorites![favoriteIndex], onCreatorSelected: widget.onCreatorSelected);
      }
      currentIndex += _favorites!.length;
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
