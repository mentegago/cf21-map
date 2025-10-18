import 'package:flutter/material.dart';
import '../../models/creator.dart';
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
  State<ExpandableSearch> createState() => _ExpandableSearchState();
}

class _ExpandableSearchState extends State<ExpandableSearch> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _searchScrollController = ScrollController();
  bool _isExpanded = false;

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
                            hintText: 'Search name, booth, or fandom...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onChanged: _performSearch,
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchController,
                    builder: (context, value, _) {
                      if (value.text.isNotEmpty || widget.onClear != null) {
                        return IconButton(
                          icon: Icon(Icons.close, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
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

