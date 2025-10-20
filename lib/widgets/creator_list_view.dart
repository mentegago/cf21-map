import 'package:cf21_map_flutter/services/creator_data_service.dart';
import 'package:cf21_map_flutter/services/favorites_service.dart';
import 'package:cf21_map_flutter/utils/int_encoding.dart';
import 'package:cf21_map_flutter/widgets/creator_tile.dart';
import 'package:cf21_map_flutter/widgets/creator_tile_featured.dart';
import 'package:cf21_map_flutter/widgets/creator_tile_card.dart';
import 'dart:html' as html;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/creator.dart';
import '../services/settings_provider.dart';
import '../utils/url_encoding.dart';

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
    
    final lowerQuery = widget.searchQuery.toLowerCase().trim();
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
    final useCardView = context.select((SettingsProvider settingsProvider) => settingsProvider.useCardView);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: widget.searchQuery.isNotEmpty 
            ? _buildSearchResults(context, useCardView) 
            : _buildMainView(context, useCardView),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
          ),
          child: SegmentedButton<bool>(
            selected: useCardView ? {true} : {false},
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Compact'), icon: Icon(Icons.view_list)),
              ButtonSegment(value: true, label: Text('Card'), icon: Icon(Icons.view_agenda)),
            ],
            onSelectionChanged: (value) => context.read<SettingsProvider>().setUseCardView(value.first),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context, bool useCardView) {
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
        return useCardView ? CreatorTileCard(creator: creator, onCreatorSelected: widget.onCreatorSelected) : CreatorTile(creator: creator, onCreatorSelected: widget.onCreatorSelected);
      },
    );
  }

  Widget _buildMainView(BuildContext context, bool useCardView) {
    final theme = Theme.of(context);
    final isCreatorCustomListMode = context.select((CreatorDataProvider creatorDataProvider) => creatorDataProvider.isCreatorCustomListMode);

    final List<Creator> favorites = isCreatorCustomListMode ? [] : context.select((FavoritesService favoritesService) => favoritesService.favorites);
    // Calculate total item count for ListView.builder
    int itemCount = 0;
    
    // Featured section: header + featured creator
    itemCount += 2;
    
    // Favorites section: header + favorites + share button (if any and storage is available)
    if (favorites.isNotEmpty) {
      itemCount += 1 + favorites.length + 1; // +1 for share button
    }
    
    // All creators section: header + all creators
    itemCount += 1 + _filteredCreators.length;

    if (isCreatorCustomListMode) {
      itemCount += 1;
    }

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return _buildItemAtIndex(index, theme, favorites, isCreatorCustomListMode, useCardView);
      },
    );
  }

  Widget _buildItemAtIndex(int index, ThemeData theme, List<Creator> favorites, bool isCreatorCustomListMode, bool useCardView) {
    int currentIndex = 0;

    // Featured section
    if (index == currentIndex) {
      if (isCreatorCustomListMode) {
        return const _SeeAllCreatorsButton();
      }
      else {
        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
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
    
    if (index == currentIndex) {
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
      if (index == currentIndex) {
        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
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
      
      // Check if we're in the favorites range
      final favoriteIndex = index - currentIndex;
      if (favoriteIndex >= 0 && favoriteIndex < favorites.length) {
        return useCardView ? CreatorTileCard(creator: favorites[favoriteIndex], onCreatorSelected: widget.onCreatorSelected) : CreatorTile(creator: favorites[favoriteIndex], onCreatorSelected: widget.onCreatorSelected);
      }
      currentIndex += favorites.length;
      
      // Share Favorites button
      if (index == currentIndex) {
        return const _ShareFavorites();
      }
      currentIndex++;
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
      return useCardView ? CreatorTileCard(creator: _filteredCreators[creatorIndex], onCreatorSelected: widget.onCreatorSelected) : CreatorTile(creator: _filteredCreators[creatorIndex], onCreatorSelected: widget.onCreatorSelected);
    }
    
    currentIndex += _filteredCreators.length;

    if (isCreatorCustomListMode && index == currentIndex) {
      return _AddAllToFavoritesButton(filteredCreators: _filteredCreators);
    }
    
    return const SizedBox.shrink();
  }
}

class _SeeAllCreatorsButton extends StatelessWidget {
  const _SeeAllCreatorsButton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.16),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        spacing: 16,
        children: [
          const Text(
            "You’re currently viewing a custom creator list. Only creators in the custom list are being shown.",
            textAlign: TextAlign.center,
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.arrow_back, size: 19),
            label: const Text(
              'Return to Full Creator List',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                letterSpacing: 0.1,
              ),
            ),
            onPressed: () {
              if (kIsWeb) {
                html.window.location.assign('/');
              } 
              else {
                context.read<CreatorDataProvider>().clearCreatorCustomList();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _AddAllToFavoritesButton extends StatelessWidget {
  const _AddAllToFavoritesButton({
    required List<Creator> filteredCreators,
  }) : _filteredCreators = filteredCreators;

  final List<Creator> _filteredCreators;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: const Color.fromARGB(255, 221, 41, 101),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(color: Colors.white),
        ),
        icon: const Icon(Icons.add, size: 16, color: Colors.white),
        label: const Text(
          'Add All To Favorites',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 13,
            letterSpacing: 0.1,
            color: Colors.white,
          ),
        ),
        onPressed: () {
          final favoritesService = context.read<FavoritesService>();
          final beforeCount = favoritesService.favoriteCount;
          for (final creator in _filteredCreators) {
            favoritesService.addFavorite(creator.id);
          }
          final afterCount = favoritesService.favoriteCount;
          final addedCount = afterCount - beforeCount;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                addedCount == 0
                  ? 'All creators in the list are already in your favorites.'
                  : 'Added $addedCount creator${addedCount == 1 ? '' : 's'} to favorites.'
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}

class _ShareFavorites extends StatelessWidget {
  const _ShareFavorites();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: FilledButton.tonalIcon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          visualDensity: VisualDensity.compact,
        ),
        icon: const Icon(Icons.share, size: 16),
        label: const Text(
          'Share Favorites',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 13,
            letterSpacing: 0.1,
          ),
        ),
        onPressed: () {
          final provider = context.read<FavoritesService>();
          final listCode = IntEncoding
            .intsToStringCode(
              provider
                .favorites
                .map((creator) => creator.id)
                .toList()
              );
          
          final url = UrlEncoding.toUrl({'list': listCode});
          Clipboard.setData(ClipboardData(text: url));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Shareable Favorites URL copied!'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}
