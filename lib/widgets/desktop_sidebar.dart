import 'package:flutter/material.dart';
import '../models/creator.dart';
import 'creator_avatar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class DesktopSidebar extends StatefulWidget {
  final List<Creator> creators;
  final Creator? selectedCreator;
  final Function(Creator) onCreatorSelected;
  final VoidCallback? onClear;

  const DesktopSidebar({
    super.key,
    required this.creators,
    this.selectedCreator,
    required this.onCreatorSelected,
    this.onClear,
  });

  @override
  State<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<DesktopSidebar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _searchScrollController = ScrollController();
  List<Creator> _filteredCreators = [];
  bool _hasSearched = false;
  bool _showSearchList = true;

  @override
  void initState() {
    super.initState();
    _filteredCreators = widget.creators;
    
    // Listen to focus changes - show search list when search is focused
    _searchFocusNode.addListener(() {
      if (mounted && _searchFocusNode.hasFocus) {
        setState(() {
          _showSearchList = true;
        });
      }
    });
  }

  @override
  void didUpdateWidget(DesktopSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Hide search list when creator is selected (from search list or map)
    // This handles both initial selection and changing selection
    if (widget.selectedCreator != null && _showSearchList) {
      setState(() {
        _showSearchList = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchScrollController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    _searchScrollController.jumpTo(0);
    setState(() {
      _hasSearched = query.isNotEmpty;
      if (query.isEmpty) {
        _filteredCreators = widget.creators;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredCreators = widget.creators.where((creator) {
          return creator.name.toLowerCase().contains(lowerQuery) ||
              creator.booths.any((booth) => booth.toLowerCase().contains(lowerQuery));
        }).toList();
      }
    });
  }

  void _handleCreatorSelected(Creator creator) {
    // Hide search list when creator is selected
    setState(() {
      _showSearchList = false;
    });
    // Call the parent callback
    widget.onCreatorSelected(creator);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Search section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: _buildSearchField(context, theme, isDark),
          ),

          // Content section
          Expanded(
            child: widget.selectedCreator != null && !_showSearchList
              ? _buildCreatorDetail(context, theme)
              : _buildCreatorList(context, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Show back button if creator is selected and search list is shown, otherwise show search icon
          if (widget.selectedCreator != null && _showSearchList)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _showSearchList = false;
                });
              },
            )
          else
            const Padding(
              padding: EdgeInsets.only(left: 16),
              child: Icon(Icons.search, color: Colors.grey),
            ),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                hintText: 'Search CF21 creators...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: _performSearch,
            ),
          ),
          // Show clear search button if search field is not empty
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
              onPressed: () {
                _searchController.clear();
                widget.onClear?.call();
                _performSearch('');
              },
            )
          // Show close creator button if creator is selected
          else if (widget.selectedCreator != null)
            IconButton(
              icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
              onPressed: widget.onClear,
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildCreatorList(BuildContext context, ThemeData theme) {
    return ListView(
      controller: _searchScrollController,
      children: [
        // Search results count
        if (_hasSearched)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '${_filteredCreators.length} result${_filteredCreators.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ),

        // Featured creator (only show when not searching)
        if (!_hasSearched) ...[
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

        // All creators
        if (!_hasSearched)
          Padding(
            padding: const EdgeInsets.all(16),
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
        
        // Show "No results" if searching and no results
        if (_hasSearched && _filteredCreators.isEmpty)
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
          ..._filteredCreators.map((creator) => _buildCreatorTile(creator, context, theme)),
      ],
    );
  }

  Widget _buildFeaturedCreator(BuildContext context, ThemeData theme) {
    final featured = widget.creators.firstWhere(
      (c) => c.name.toLowerCase().contains('negi no tomodachi'),
      orElse: () => widget.creators.first,
    );

    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1976D2).withValues(alpha: 0.1),
            const Color(0xFF1976D2).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1976D2).withValues(alpha: 0.3),
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
        onTap: () => _handleCreatorSelected(featured),
      ),
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
      onTap: () => _handleCreatorSelected(creator),
    );
  }

  Widget _buildCreatorDetail(BuildContext context, ThemeData theme) {
    final creator = widget.selectedCreator!;
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CreatorAvatar(creator: creator),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        creator.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        creator.boothsDisplay,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Share',
                  onPressed: () => _shareCreator(context),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),

            // Event day
            Row(
              children: [
                Icon(Icons.calendar_today, color: _getDayColor(creator.day), size: 20),
                const SizedBox(width: 8),
                Text(
                  creator.dayDisplay,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _getDayColor(creator.day),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Informations
            ...creator.informations.map((info) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    info.content,
                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),

            // URLs
            if (creator.urls.isNotEmpty) ...[
              const Text(
                'Links',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: creator.urls.map((link) {
                  return ActionChip(
                    avatar: const Icon(Icons.link, size: 18),
                    label: Text(link.title.isNotEmpty ? link.title : link.url),
                    onPressed: () {
                      try {
                        launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    },
                    backgroundColor: theme.colorScheme.primaryContainer,
                    side: BorderSide(color: theme.colorScheme.primary),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Booths
            Text(
              'Booth Location${creator.booths.length > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: creator.booths.map((booth) {
                return Chip(
                  avatar: Icon(Icons.location_on, size: 18, color: theme.colorScheme.primary),
                  label: Text(booth),
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Color _getDayColor(String day) {
    switch (day) {
      case 'BOTH':
        return Colors.purple;
      case 'SAT':
        return Colors.blue;
      case 'SUN':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _shareCreator(BuildContext context) async {
    try {
      final encodedName = Uri.encodeComponent(widget.selectedCreator!.name);
      final shareUrl = 'https://cf21.nnt.gg/?creator=$encodedName';
      
      await Clipboard.setData(ClipboardData(text: shareUrl));

      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Link copied: ${widget.selectedCreator!.name}'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not copy link. Please copy manually from the URL bar.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}