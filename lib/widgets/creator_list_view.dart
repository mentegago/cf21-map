import 'package:flutter/material.dart';
import '../models/creator.dart';
import 'creator_avatar.dart';

class CreatorListView extends StatelessWidget {
  final List<Creator> creators;
  final List<Creator> filteredCreators;
  final bool hasSearched;
  final Function(Creator) onCreatorSelected;
  final ScrollController? scrollController;
  final bool showFeaturedCreator;

  const CreatorListView({
    super.key,
    required this.creators,
    required this.filteredCreators,
    required this.hasSearched,
    required this.onCreatorSelected,
    this.scrollController,
    this.showFeaturedCreator = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      controller: scrollController,
      children: [
        // Search results count
        if (hasSearched)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '${filteredCreators.length} result${filteredCreators.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ),

        // Featured creator (only show when not searching and enabled)
        if (!hasSearched && showFeaturedCreator) ...[
          Padding(
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
          ),
          _buildFeaturedCreator(context, theme),
        ],

        
        // Show "No results" if searching and no results
        if (hasSearched && filteredCreators.isEmpty)
          Center(
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
          )
        else
          ...filteredCreators.map((creator) => _buildCreatorTile(creator, context, theme)),
      ],
    );
  }

  Widget _buildFeaturedCreator(BuildContext context, ThemeData theme) {
    final featured = creators.firstWhere(
      (c) => c.name.toLowerCase().contains('negi no tomodachi'),
      orElse: () => creators.first,
    );

    final section = _getBoothSection(featured);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getSectionColor(section).withValues(alpha: 0.1),
                _getSectionColor(section).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getSectionColor(section).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: ListTile(
            leading: CreatorAvatar(creator: featured),
            title: Text(
              featured.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${featured.boothsDisplay} • ${featured.dayDisplay}',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
            trailing: const Icon(Icons.location_on),
            onTap: () => onCreatorSelected(featured),
          ),
        ),
        Padding(
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
        ),
      ],
    );
  }

  Widget _buildCreatorTile(Creator creator, BuildContext context, ThemeData theme) {
    return ListTile(
      leading: CreatorAvatar(creator: creator),
      title: Text(
        creator.name,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${creator.boothsDisplay} • ${creator.dayDisplay}',
        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
      ),
      trailing: const Icon(Icons.location_on),
      onTap: () => onCreatorSelected(creator),
    );
  }

  String _getBoothSection(Creator creator) {
    if (creator.booths.isEmpty) return '?';
    final firstBooth = creator.booths.first;
    final hyphen = firstBooth.indexOf('-');
    if (hyphen > 0) {
      return firstBooth.substring(0, hyphen).toUpperCase();
    }
    return firstBooth.isNotEmpty ? firstBooth.substring(0, 1).toUpperCase() : '?';
  }

  Color _getSectionColor(String section) {
    const List<Color> palette = [
      Color(0xFF1976D2), // blue 700
      Color(0xFF388E3C), // green 600
      Color(0xFFEF6C00), // orange 800
      Color(0xFF7B1FA2), // purple 700
      Color(0xFFD32F2F), // red 700
      Color(0xFF00838F), // cyan 800
      Color(0xFF558B2F), // light green 700
      Color(0xFFFF8F00), // amber 800
    ];
    final idx = section.codeUnitAt(0) % palette.length;
    return palette[idx];
  }
}
