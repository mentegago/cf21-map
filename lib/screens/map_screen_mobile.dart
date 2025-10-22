import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/creator.dart';
import '../models/map_cell.dart';
import '../services/creator_data_service.dart';
import '../widgets/fab_button.dart';
import '../widgets/map_viewer.dart';
import '../widgets/mobile/creator_detail_sheet.dart';
import '../widgets/mobile/expandable_search.dart';
import '../widgets/version_notification.dart';

class MapScreenMobileView extends StatefulWidget {
  final List<MergedCell> mergedCells;
  final int rows;
  final int cols;
  final Future<void> Function() onClearSelection;
  final ValueChanged<Creator> onCreatorSelected;
  final void Function(String?) onBoothTap;

  const MapScreenMobileView({
    super.key,
    required this.mergedCells,
    required this.rows,
    required this.cols,
    required this.onClearSelection,
    required this.onCreatorSelected,
    required this.onBoothTap,
  });

  @override
  State<MapScreenMobileView> createState() => _MapScreenMobileViewState();
}

class _MapScreenMobileViewState extends State<MapScreenMobileView> with SingleTickerProviderStateMixin {
  late final AnimationController _detailAnimationController;
  late final Animation<Offset> _detailSlideAnimation;
  final GlobalKey<ExpandableSearchState> _expandableSearchKey = GlobalKey<ExpandableSearchState>();
  Creator? _visibleCreator;
  int? _lastCreatorId;
  bool _isAnimatingOut = false;

  @override
  void initState() {
    super.initState();
    _detailAnimationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _detailSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _detailAnimationController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  @override
  void dispose() {
    _detailAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final creators = context.select((CreatorDataProvider p) => p.creators);
    final selectedCreator = context.select((CreatorDataProvider p) => p.selectedCreator);
    final isCreatorCustomListMode = context.select((CreatorDataProvider p) => p.isCreatorCustomListMode);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncVisibleCreator(selectedCreator);
    });

    return Stack(
      children: [
        MapViewer(
          mergedCells: widget.mergedCells,
          rows: widget.rows,
          cols: widget.cols,
          onBoothTap: widget.onBoothTap,
        ),
        const FABButton(isDesktop: false),
        if (isCreatorCustomListMode)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              elevation: 6,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "You're viewing a curated creator list",
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Only the creators selected by the list owner are shown on the map. Tap the search box above to see the creator list.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const VersionNotification(isDesktop: false),
        if (_visibleCreator != null)
          SlideTransition(
            position: _detailSlideAnimation,
            child: CreatorDetailSheet(
              creator: _visibleCreator!,
              onClose: _dismissDetail,
              onRequestSearch: _handleRequestSearch,
            ),
          ),
        if (creators != null)
          ExpandableSearch(
            key: _expandableSearchKey,
            creators: creators,
            onCreatorSelected: widget.onCreatorSelected,
            onClear: selectedCreator != null ? _dismissDetail : null,
            selectedCreator: selectedCreator,
          ),
      ],
    );
  }

  void _handleRequestSearch(String query) {
    _expandableSearchKey.currentState?.performSearch(query);
  }

  void _syncVisibleCreator(Creator? selected) {
    if (!mounted) return;
    final selectedId = selected?.id;

    if (selected != null) {
      final isNewSelection = selectedId != _lastCreatorId || !identical(selected, _visibleCreator);
      if (isNewSelection || _visibleCreator == null) {
        setState(() {
          _visibleCreator = selected;
          _lastCreatorId = selectedId;
        });
      }
      if (_isAnimatingOut) {
        _isAnimatingOut = false;
      }
      if (_detailAnimationController.status != AnimationStatus.forward && _detailAnimationController.value != 1.0) {
        _detailAnimationController.forward();
      }
    } else {
      if (_visibleCreator != null && !_isAnimatingOut) {
        _isAnimatingOut = true;
        _detailAnimationController.reverse().whenCompleteOrCancel(() {
          if (!mounted) return;
          setState(() {
            _visibleCreator = null;
            _lastCreatorId = null;
          });
          _isAnimatingOut = false;
        });
      }
    }
  }

  void _dismissDetail() {
    if (_visibleCreator == null) {
      widget.onClearSelection();
      return;
    }
    if (_isAnimatingOut) return;

    _isAnimatingOut = true;
    _detailAnimationController.reverse().whenCompleteOrCancel(() async {
      if (!mounted) return;
      setState(() {
        _visibleCreator = null;
        _lastCreatorId = null;
      });
      await widget.onClearSelection();
      if (mounted) {
        _isAnimatingOut = false;
      }
    });
  }
}
