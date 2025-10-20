import 'package:cf21_map_flutter/models/creator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'creator_avatar.dart';

class CreatorTileCard extends StatefulWidget {
  const CreatorTileCard({
    super.key,
    required this.creator,
    required this.onCreatorSelected
  });

  final Creator creator;
  final Function(Creator) onCreatorSelected;

  @override
  State<CreatorTileCard> createState() => _CreatorTileCardState();
}

class _CreatorTileCardState extends State<CreatorTileCard> {
  bool _isHovered = false;

  void _handleHover(PointerEvent event) {
    // Ignore hover events from touch devices
    if (event.kind == PointerDeviceKind.touch) {
      return;
    }
    
    if (!_isHovered) {
      setState(() {
        _isHovered = true;
      });
    }
  }

  void _handleExit(PointerEvent event) {
    // Ignore exit events from touch devices
    if (event.kind == PointerDeviceKind.touch) {
      return;
    }
    
    if (_isHovered) {
      setState(() {
        _isHovered = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onHover: _handleHover,
      onExit: _handleExit,
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => widget.onCreatorSelected(widget.creator),
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image section (fixed height)
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: Transform.scale(
                        scale: 1.3,
                        child: CachedNetworkImage(
                          imageUrl: widget.creator.circleCut ?? '',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: _getSectionColor(_getBoothSection(widget.creator)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: _getSectionColor(_getBoothSection(widget.creator)),
                          )
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.creator.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.creator.boothsDisplay,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Horizontal scrolling fandoms
                        if (widget.creator.fandoms.isNotEmpty)
                          Container(
                            height: 32,
                            margin: const EdgeInsets.only(bottom: 16),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              scrollDirection: Axis.horizontal,
                              itemCount: widget.creator.fandoms.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 6),
                              itemBuilder: (context, index) {
                                final fandom = widget.creator.fandoms[index];
                                return Chip(
                                  label: Text(
                                    fandom,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                  side: BorderSide(
                                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                ),
              ],
            ),
          ),
        ),
      ),
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