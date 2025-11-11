import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/creator.dart';
import '../../services/creator_data_service.dart';
import '../../utils/int_encoding.dart';
import '../creator_detail_content.dart';
import '../creator_list_view.dart';

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
  bool _showSearchList = true;

  @override
  void initState() {
    super.initState();
    
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
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
            ),
            child: _buildSearchField(context, theme, isDark),
          ),

          // Content section
          Expanded(
            child: IndexedStack(
              index: widget.selectedCreator != null && !_showSearchList ? 0 : 1,
              children: [
                _buildCreatorDetail(context, theme),
                _buildCreatorList(context, theme),
              ],
            ),
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
                hintText: 'Search name, booth, or fandom...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: _performSearch,
              onSubmitted: _handleSearchSubmitted,
            ),
          ),
          // Show clear search button if search field is not empty
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, _) {
              if (value.text.isNotEmpty) {
                return IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
                  onPressed: () {
                    _searchController.clear();
                    widget.onClear?.call();
                    _performSearch('');
                  },
                );
              } else if (widget.selectedCreator != null) {
                return IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
                  onPressed: widget.onClear,
                );
              } else {
                return const SizedBox(width: 8);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCreatorList(BuildContext context, ThemeData theme) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) {
        return CreatorListView(
          creators: widget.creators,
          searchQuery: value.text,
          onCreatorSelected: _handleCreatorSelected,
          scrollController: _searchScrollController,
          onShouldHideListScreen: () {},
          onClearSearch: () {
            _searchController.clear();
            _performSearch('');
          },
          onSearchQueryChanged: (query) {
            _searchController.text = query;
            _performSearch(query);
          },
        );
      },
    );
  }


  Widget _buildCreatorDetail(BuildContext context, ThemeData theme) {
    final creator = widget.selectedCreator;
    if (creator == null) {
      return const SizedBox.shrink();
    }
    
    return SingleChildScrollView(
      child: CreatorDetailContent(
        creator: creator,
        showShareButton: true,
        showFavoriteButton: true,
        showCloseButton: false,
        onRequestSearch: _handleRequestSearch,
      ),
    );
  }

  void _handleRequestSearch(String query) {
    setState(() {
      _searchController.text = query;
      _showSearchList = true;
    });
    
    _performSearch(query);
  }

  void _handleSearchSubmitted(String text) {
    // Router function - delegates to specific handlers based on URL pattern
    if (text.contains('?list=')) {
      _handleListUrl(text);
    } else if (text.contains('?creator_id=')) {
      _handleCreatorIdUrl(text);
    } else if (text.contains('?creator=')) {
      _handleCreatorUrl(text);
    } else if (text.contains('?custom_list=')) {
      _handleCustomListUrl(text);
    }
  }

  void _handleListUrl(String text) {
    try {
      // Parse the URL
      final uri = Uri.tryParse(text);
      if (uri == null) {
        return; // Invalid URL, fail silently
      }

      // Extract the list query parameter
      final listParam = uri.queryParameters['list'];
      if (listParam == null || listParam.isEmpty) {
        return; // No list parameter, fail silently
      }

      // Decode the compressed list
      final idList = IntEncoding.stringCodeToInts(listParam);
      if (idList.isEmpty) {
        return; // Empty or invalid list, fail silently
      }

      // Set creator custom list with specified flags
      final creatorProvider = context.read<CreatorDataProvider>();
      creatorProvider.setCreatorCustomList(
        idList,
        showAddAllToFavorites: true,
        shouldRefreshOnReturn: false,
      );

      // Clear search controller only on success
      _searchController.clear();
      _performSearch('');
    } catch (e) {
      // Fail silently on any error
      return;
    }
  }

  void _handleCreatorIdUrl(String text) {
    try {
      // Parse the URL
      final uri = Uri.tryParse(text);
      if (uri == null) {
        return; // Invalid URL, fail silently
      }

      // Extract the creator_id query parameter
      final creatorIdParam = uri.queryParameters['creator_id'];
      if (creatorIdParam == null || creatorIdParam.isEmpty) {
        return; // No creator_id parameter, fail silently
      }

      // Parse creator ID
      final creatorId = int.tryParse(creatorIdParam);
      if (creatorId == null) {
        return; // Invalid creator ID, fail silently
      }

      // Get creator by ID
      final creatorProvider = context.read<CreatorDataProvider>();
      final creator = creatorProvider.getCreatorById(creatorId);
      if (creator == null) {
        return; // Creator not found, fail silently
      }

      // Select the creator
      widget.onCreatorSelected(creator);

      // Clear search controller only on success
      _searchController.clear();
      _performSearch('');
    } catch (e) {
      // Fail silently on any error
      return;
    }
  }

  void _handleCreatorUrl(String text) {
    try {
      // Parse the URL
      final uri = Uri.tryParse(text);
      if (uri == null) {
        return; // Invalid URL, fail silently
      }

      // Extract the creator query parameter
      final creatorParam = uri.queryParameters['creator'];
      if (creatorParam == null || creatorParam.isEmpty) {
        return; // No creator parameter, fail silently
      }

      // Decode and normalize name (replace + with space, trim)
      final searchName = Uri.decodeComponent(creatorParam.replaceAll('+', ' ')).trim().toLowerCase();
      if (searchName.isEmpty) {
        return; // Empty search name, fail silently
      }

      // Get all creators from provider
      final creatorProvider = context.read<CreatorDataProvider>();
      final creators = creatorProvider.creators;
      if (creators == null || creators.isEmpty) {
        return; // No creators available, fail silently
      }

      // Find creator by name (case-insensitive, partial match)
      Creator? creator;
      try {
        creator = creators.firstWhere(
          (c) => c.name.toLowerCase().contains(searchName),
          orElse: () => creators.firstWhere(
            (c) => c.name.toLowerCase() == searchName,
            orElse: () => creators.first, // fallback, won't be used if null check below
          ),
        );
        
        // Only select if we found a match
        if (!creator.name.toLowerCase().contains(searchName)) {
          return; // No match found, fail silently
        }
      } catch (e) {
        return; // No match found, fail silently
      }

      // Select the creator
      widget.onCreatorSelected(creator);

      // Clear search controller only on success
      _searchController.clear();
      _performSearch('');
    } catch (e) {
      // Fail silently on any error
      return;
    }
  }

  void _handleCustomListUrl(String text) {
    try {
      // Parse the URL
      final uri = Uri.tryParse(text);
      if (uri == null) {
        return; // Invalid URL, fail silently
      }

      // Extract the custom_list query parameter
      final customListParam = uri.queryParameters['custom_list'];
      if (customListParam == null || customListParam.isEmpty) {
        return; // No custom_list parameter, fail silently
      }

      // Parse comma-separated creator IDs
      final idStrings = customListParam.split(',');
      final idList = idStrings
          .map((idStr) => int.tryParse(idStr.trim()))
          .where((id) => id != null)
          .cast<int>()
          .toList();

      if (idList.isEmpty) {
        return; // Empty or invalid list, fail silently
      }

      // Set creator custom list with specified flags
      final creatorProvider = context.read<CreatorDataProvider>();
      creatorProvider.setCreatorCustomList(
        idList,
        showAddAllToFavorites: true,
        shouldRefreshOnReturn: false,
      );

      // Clear search controller only on success
      _searchController.clear();
      _performSearch('');
    } catch (e) {
      // Fail silently on any error
      return;
    }
  }
}