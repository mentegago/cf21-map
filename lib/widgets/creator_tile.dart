import 'package:cf21_map_flutter/models/creator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import 'creator_avatar.dart';
import 'sample_works_gallery.dart';

class CreatorTile extends StatefulWidget {
  const CreatorTile({
    super.key,
    required this.creator,
    required this.onCreatorSelected
  });

  final Creator creator;
  final Function(Creator) onCreatorSelected;

  @override
  State<CreatorTile> createState() => _CreatorTileState();
}

class _CreatorTileState extends State<CreatorTile> {
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
      child: Container(
        color: _isHovered 
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
          : Colors.transparent,
        child: ListTile(
          leading: CreatorAvatar(creator: widget.creator),
          trailing: widget.creator.sampleworksImages.isNotEmpty 
            ? IconButton(
              icon: const Icon(Icons.photo_library),
              onPressed: () {
                showSampleWorksGallery(context: context, imageUrls: widget.creator.sampleworksImages);
              },
            ) 
            : null,
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
    );
  }
}