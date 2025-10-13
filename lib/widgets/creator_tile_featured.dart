import 'package:cf21_map_flutter/widgets/creator_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../models/creator.dart';

class CreatorTileFeatured extends StatefulWidget {
  const CreatorTileFeatured({
    super.key,
    required this.creator,
    required this.onCreatorSelected
  });

  final Creator creator;
  final Function(Creator) onCreatorSelected;

  @override
  State<CreatorTileFeatured> createState() => _CreatorTileFeaturedState();
}

class _CreatorTileFeaturedState extends State<CreatorTileFeatured> {
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

    // Use a static color for the featured creator tile.
    const Color staticFeaturedColor = Color.fromARGB(255, 25, 210, 40); // blue 700

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onHover: _handleHover,
          onExit: _handleExit,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  staticFeaturedColor.withValues(alpha: 0.1),
                  staticFeaturedColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: staticFeaturedColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Container(
              color: _isHovered 
                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2)
                : Colors.transparent,
              child: ListTile(
                leading: CreatorAvatar(creator: widget.creator),
                title: Text(
                  widget.creator.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${widget.creator.boothsDisplay} • ${widget.creator.dayDisplay}',
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                onTap: () => widget.onCreatorSelected(widget.creator),
              ),
            ),
          ),
        ),
      ],
    );
  }
}