import 'package:cf21_map_flutter/models/creator.dart';
import 'package:cf21_map_flutter/widgets/creator_list_view.dart';
import 'package:flutter/material.dart';

import 'creator_avatar.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onHover: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        color: _isHovered 
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
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
    );
  }
}