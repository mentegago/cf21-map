import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/creator.dart';
import '../../services/creator_data_service.dart';
import '../../utils/int_encoding.dart';
import '../creator_list_view.dart';

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
  State<ExpandableSearch> createState() => ExpandableSearchState();
}

class ExpandableSearchState extends State<ExpandableSearch> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _searchScrollController = ScrollController();
  bool _isExpanded = false;

  void performSearch(String query) {
    setState(() {
      _searchController.text = query;
      _isExpanded = true;
    });
    _performSearch(query);
  }

  @override
  void initState() {
    super.initState();

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
    _searchScrollController.jumpTo(0);
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
    });
    _collapse();
    widget.onClear?.call();
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
      setState(() {
        _searchController.clear();
      });
      _collapse();
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
      setState(() {
        _searchController.clear();
      });
      _collapse();
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
      final searchName = Uri.decodeComponent(creatorParam.replaceAll('+', ' '))
          .trim()
          .toLowerCase();
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
            orElse: () =>
                creators.first, // fallback, won't be used if null check below
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
      setState(() {
        _searchController.clear();
      });
      _collapse();
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
      setState(() {
        _searchController.clear();
      });
      _collapse();
    } catch (e) {
      // Fail silently on any error
      return;
    }
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
                      // Results list
                      Expanded(
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchController,
                          builder: (context, value, _) {
                            return CreatorListView(
                              creators: widget.creators,
                              searchQuery: value.text,
                              onCreatorSelected: _handleCreatorTap,
                              scrollController: _searchScrollController,
                              onShouldHideListScreen: () {
                                _collapse();
                              },
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
            child: Container(
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
                            hintText: 'Search name, booth, or fandom...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          onChanged: _performSearch,
                          onSubmitted: _handleSearchSubmitted,
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, _) {
                      if (value.text.isNotEmpty || widget.onClear != null) {
                        return IconButton(
                          icon: Icon(Icons.close,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                              size: 20),
                          onPressed: _handleClear,
                        );
                      } else {
                        return const SizedBox(width: 8);
                      }
                    },
                  )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
