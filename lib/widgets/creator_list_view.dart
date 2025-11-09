import 'dart:math';

import 'package:cf21_map_flutter/services/creator_data_service.dart';
import 'package:cf21_map_flutter/services/favorites_service.dart';
import 'package:cf21_map_flutter/widgets/creator_tile.dart';
import 'package:cf21_map_flutter/widgets/creator_tile_card.dart';
import 'dart:html' as html;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/creator.dart';
import '../services/settings_provider.dart';
import '../utils/fuzzy_score.dart';
import '../utils/string_utils.dart';

class CreatorListView extends StatefulWidget {
  final List<Creator> creators;
  final String searchQuery;
  final Function(Creator) onCreatorSelected;
  final ScrollController? scrollController;
  final VoidCallback onShouldHideListScreen;
  final VoidCallback? onClearSearch;
  
  const CreatorListView({
    super.key,
    required this.creators,
    required this.searchQuery,
    required this.onCreatorSelected,
    required this.onShouldHideListScreen,
    this.scrollController,
    this.onClearSearch,
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
    
    final trimmedQuery = widget.searchQuery.trim().toLowerCase();
    final optimizedQuery = optimizeStringFormat(trimmedQuery);
    final optimizedBoothQuery = optimizedBoothFormat(trimmedQuery);  // Ensure writing things like "AB08" would output put "ab8"

    _cachedFilteredCreators = widget.creators.map((creator) {
      var maxScore = -1.0;
      var maxScoreStringScore = -1.0;
      
      // Check by booth number
      for (final booth in creator.searchOptimizedBooths) {
        if (booth.startsWith(optimizedBoothQuery)) {
          maxScore = max(maxScore, 2.0);
          maxScoreStringScore = max(maxScoreStringScore, 2.0);
          break;
        }
      }

      // Check by name
      final nameScore = fuzzyScore(optimizedQuery, creator.name.toLowerCase());
      final nameStringScore = optimizedQuery.length / creator.name.length.toDouble();

      if (nameScore.matched && nameStringScore > maxScoreStringScore) {
        maxScore = max(maxScore, nameScore.score);
        maxScoreStringScore = nameStringScore;
      }

      // Fandom check - Ensure writing things like "BA" or "ZZZ" would output put "Blue Archive" and "Zenless Zone Zero" above other creators.
      for (final fandom in creator.fandoms) {
        final fandomScore = fuzzyScore(optimizedQuery, fandom.toLowerCase());
        final fandomStringScore = optimizedQuery.length / fandom.length.toDouble();

        if (fandomScore.matched && fandomStringScore > maxScoreStringScore) {
          maxScore = max(maxScore, fandomScore.score);
          maxScoreStringScore = fandomStringScore;
        }
      }

      // Reverse fandom check - Fuzzy search for fandoms that are similar to the query.
      for (final fandom in creator.searchOptimizedFandoms) {
        final fandomScore = fuzzyScore(fandom, trimmedQuery);
        final fandomStringScore = fandom.length / trimmedQuery.length.toDouble();

        if (fandomScore.matched && fandomStringScore > maxScoreStringScore) {
          maxScore = max(maxScore, fandomScore.score);
          maxScoreStringScore = fandomStringScore;
        }
      }

      if (maxScore < 0.7) return null;

      return (creator, maxScore, maxScoreStringScore);
    })
    .nonNulls
    .sorted((a, b) {
      final scoreCmp = b.$2.compareTo(a.$2);
      if (scoreCmp != 0) return scoreCmp;

      final scoreStringCmp = b.$3.compareTo(a.$3);
      if (scoreStringCmp != 0) return scoreStringCmp;

      return a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase());
    })
    .map((result) => result.$1)
    .toList();
    
    return _cachedFilteredCreators!;
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
            : _buildMainView(context, useCardView, widget.onShouldHideListScreen),
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
          // Results count header with "Show on Map" button
          return _SearchResultsHeader(
            resultCount: _filteredCreators.length,
            filteredCreators: _filteredCreators,
            onShouldHideListScreen: widget.onShouldHideListScreen,
            onClearSearch: widget.onClearSearch,
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

  Widget _buildMainView(BuildContext context, bool useCardView, VoidCallback onShouldHideListScreen) {
    final theme = Theme.of(context);
    final isCreatorCustomListMode = context.select((CreatorDataProvider creatorDataProvider) => creatorDataProvider.isCreatorCustomListMode);
    final showAddAllToFavorites = context.select((CreatorDataProvider creatorDataProvider) => creatorDataProvider.showAddAllToFavorites);
    final shouldRefreshOnReturn = context.select((CreatorDataProvider creatorDataProvider) => creatorDataProvider.shouldRefreshOnReturn);
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
        return _buildItemAtIndex(index, theme, favorites, isCreatorCustomListMode, useCardView, showAddAllToFavorites, shouldRefreshOnReturn, onShouldHideListScreen);
      },
    );
  }

  Widget _buildItemAtIndex(
    int index, 
    ThemeData theme, 
    List<Creator> favorites, 
    bool isCreatorCustomListMode, 
    bool useCardView, 
    bool showAddAllToFavorites,
    bool shouldRefreshOnReturn,
    VoidCallback onShouldHideListScreen,
  ) {
    int currentIndex = 0;

    // Featured section
    if (index == currentIndex) {
      if (isCreatorCustomListMode) {
        return _SeeAllCreatorsButton(onShouldHideListScreen: onShouldHideListScreen);
      }
      else {
        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
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
        ? CreatorTile(creator: featuredCreator, onCreatorSelected: widget.onCreatorSelected)
        : const SizedBox.shrink();
    }
    currentIndex++;
    
    // Favorites section
    if (favorites.isNotEmpty) {
      if (index == currentIndex) {
        return _FavoritesSectionHeader(onShouldHideListScreen: onShouldHideListScreen);
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
          isCreatorCustomListMode ? 'Custom Creators List' : 'All Creators',
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

    if (index == currentIndex && isCreatorCustomListMode && showAddAllToFavorites) {
      return _AddAllToFavoritesButton(filteredCreators: _filteredCreators);
    }
    currentIndex++;
    
    // All creators items
    final creatorIndex = index - currentIndex;
    if (creatorIndex >= 0 && creatorIndex < _filteredCreators.length) {
      return useCardView ? CreatorTileCard(creator: _filteredCreators[creatorIndex], onCreatorSelected: widget.onCreatorSelected) : CreatorTile(creator: _filteredCreators[creatorIndex], onCreatorSelected: widget.onCreatorSelected);
    }
    
    currentIndex += _filteredCreators.length;
    
    return const SizedBox.shrink();
  }
}

void _shareFavorites(BuildContext context) {
  final provider = context.read<FavoritesService>();
  final url = provider.getShareableUrl();
  Clipboard.setData(ClipboardData(text: url));
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Shareable Favorites URL copied!'),
      duration: Duration(seconds: 2),
    ),
  );
}

class _SeeAllCreatorsButton extends StatelessWidget {
  final VoidCallback onShouldHideListScreen;
  const _SeeAllCreatorsButton({
    required this.onShouldHideListScreen,
  });

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
            "You're viewing a curated creator list. Only the creators selected by the list owner are shown on the map.",
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
              if (kIsWeb && context.read<CreatorDataProvider>().shouldRefreshOnReturn) {
                html.window.location.assign('/');
              } 
              else {
                context.read<CreatorDataProvider>().clearCreatorCustomList();
                onShouldHideListScreen();
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
          'Add All to Favorites',
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
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          visualDensity: VisualDensity.compact,
          backgroundColor: const Color.fromARGB(255, 221, 41, 101),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(color: Colors.white),
        ),
        icon: const Icon(Icons.share, size: 16, color: Colors.white),
        label: const Text(
          'Share Favorites',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 13,
            letterSpacing: 0.1,
            color: Colors.white,
          ),
        ),
        onPressed: () => _shareFavorites(context),
      ),
    );
  }
}

class _SearchResultsHeader extends StatelessWidget {
  final int resultCount;
  final List<Creator> filteredCreators;
  final VoidCallback onShouldHideListScreen;
  final VoidCallback? onClearSearch;
  
  const _SearchResultsHeader({
    required this.resultCount,
    required this.filteredCreators,
    required this.onShouldHideListScreen,
    this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$resultCount result${resultCount == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          if (filteredCreators.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                final creatorProvider = context.read<CreatorDataProvider>();
                final searchResultIds = filteredCreators.map((c) => c.id).toList();
                creatorProvider.setCreatorCustomList(searchResultIds, showAddAllToFavorites: true, shouldRefreshOnReturn: false);
                onClearSearch?.call();
                onShouldHideListScreen();
              },
              icon: Icon(
                Icons.map,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              label: Text(
                'Show on Map',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _FavoritesSectionHeader extends StatelessWidget {
  final VoidCallback onShouldHideListScreen;
  const _FavoritesSectionHeader({
    required this.onShouldHideListScreen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Favorites',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              final creatorProvider = context.read<CreatorDataProvider>();
              final favorites = context.read<FavoritesService>().favorites;
              final favoriteIds = favorites.map((c) => c.id).toList();
              creatorProvider.setCreatorCustomList(favoriteIds, showAddAllToFavorites: false, shouldRefreshOnReturn: false);
              onShouldHideListScreen();
            },
            icon: Icon(
              Icons.map,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            label: Text(
              'Show on Map',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          TextButton.icon(
            onPressed: () => _shareFavorites(context),
            icon: Icon(
              Icons.share,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            label: Text(
              'Share',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
