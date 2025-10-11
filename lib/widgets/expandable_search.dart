import 'package:flutter/material.dart';
import '../models/creator.dart';
import 'creator_avatar.dart';

class ExpandableSearch extends StatefulWidget {
  final List<Creator> creators;
  final Function(Creator) onCreatorSelected;
  final VoidCallback? onClear;
  final Creator? selectedCreator;

  const ExpandableSearch({
    super.key,
    required this.creators,
    required this.onCreatorSelected,
    this.onClear,
    this.selectedCreator,
  });

  @override
  State<ExpandableSearch> createState() => _ExpandableSearchState();
}

class _ExpandableSearchState extends State<ExpandableSearch> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Creator> _filteredCreators = [];
  bool _isExpanded = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _filteredCreators = widget.creators;
    
    // Listen to focus changes to expand (but not collapse)
    _focusNode.addListener(() {
      if (mounted && !_isExpanded && _focusNode.hasFocus) {
        setState(() {
          _isExpanded = true;
        });
      }
    });
  }

  @override
  void didUpdateWidget(ExpandableSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset search when detail sheet is closed (selectedCreator becomes null)
    if (oldWidget.selectedCreator != null && widget.selectedCreator == null) {
      setState(() {
        _searchController.clear();
        _hasSearched = false;
        _filteredCreators = widget.creators;
        _isExpanded = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
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

  int _getItemCount() {
    // Add 1 for featured creator when not searching
    return !_hasSearched ? _filteredCreators.length + 1 : _filteredCreators.length;
  }

  Widget _buildFeaturedCreatorTile(BuildContext context) {
    final theme = Theme.of(context);
    // Find "Negi no Tomodachi"
    final featured = widget.creators.firstWhere(
      (c) => c.name.toLowerCase().contains('negi no tomodachi'),
      orElse: () => widget.creators.first,
    );
    
    final section = _getBoothSection(featured);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
            onTap: () => _handleCreatorTap(featured),
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

  void _collapse() {
    _focusNode.unfocus();
    setState(() {
      _isExpanded = false;
    });
  }

  void _handleCreatorTap(Creator creator) {
    _collapse();
    widget.onCreatorSelected(creator);
  }

  void _handleClear() {
    setState(() {
      _searchController.clear();
      _hasSearched = false;
      _filteredCreators = widget.creators;
    });
    _collapse();
    widget.onClear?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-screen overlay (always present, just hidden when not expanded)
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_isExpanded,
            child: AnimatedOpacity(
          opacity: _isExpanded ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            color: theme.colorScheme.surface,
            child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 80), // Space for search bar
                      
                      // Results count
                      if (_hasSearched)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                          '${_filteredCreators.length} result${_filteredCreators.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 14,
                          ),
                            ),
                          ),
                        ),
                      
                      // Results list
                      Expanded(
                        child: _filteredCreators.isEmpty && _hasSearched
                            ? Center(
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
                              )
                            : ListView.builder(
                                itemCount: _getItemCount(),
                                itemBuilder: (context, index) {
                                  // Show featured creator at top when no search query
                                  if (!_hasSearched && index == 0) {
                                    return _buildFeaturedCreatorTile(context);
                                  }
                                  final creatorIndex = !_hasSearched ? index - 1 : index;
                                  final creator = _filteredCreators[creatorIndex];
                                  return _buildCreatorTile(creator, context);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Search bar (always on top)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(
            child:         Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            // White search bar in light mode, dark neutral in dark mode
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
                  if (_isExpanded)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: _collapse,
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Icon(Icons.search, color: Colors.grey),
                    ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (!_focusNode.hasFocus) {
                          _focusNode.requestFocus();
                        }
                      },
                      child: AbsorbPointer(
                        absorbing: false,
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          decoration: const InputDecoration(
                            hintText: 'Search CF21 creators...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onChanged: _performSearch,
                        ),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty && widget.onClear != null)
                    IconButton(
                      icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
                      onPressed: _handleClear,
                    )
                  else
                    const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCreatorTile(Creator creator, BuildContext context) {
    final theme = Theme.of(context);
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
      onTap: () => _handleCreatorTap(creator),
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

