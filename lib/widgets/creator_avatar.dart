import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/creator.dart';

class CreatorAvatar extends StatefulWidget {
  final Creator creator;
  final double radius;

  const CreatorAvatar({
    super.key,
    required this.creator,
    this.radius = 20,
  });

  @override
  State<CreatorAvatar> createState() => _CreatorAvatarState();
}

class _CreatorAvatarState extends State<CreatorAvatar> {
  bool _imageLoadFailed = false;

  @override
  void didUpdateWidget(CreatorAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset failure state if creator changed
    if (oldWidget.creator.profileImage != widget.creator.profileImage) {
      _imageLoadFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.creator.profileImage != null && !_imageLoadFailed) {
      // Check if it's a URL (starts with http/https) or a local asset
      final isUrl = widget.creator.profileImage!.startsWith('http://') ||
                   widget.creator.profileImage!.startsWith('https://');

      return CircleAvatar(
        backgroundImage: isUrl
            ? NetworkImage(widget.creator.profileImage!) as ImageProvider<Object>
            : AssetImage(widget.creator.profileImage!) as ImageProvider<Object>,
        backgroundColor: Colors.transparent,
        radius: widget.radius,
        onBackgroundImageError: isUrl ? (exception, stackTrace) {
          if (mounted) {
            setState(() {
              _imageLoadFailed = true;
            });
          }
          debugPrint('Failed to load network image: ${widget.creator.profileImage}');
        } : null,
      );
    }

    // Fallback: colored circle with section letter
    final section = _getBoothSection(widget.creator);
    return CircleAvatar(
      backgroundColor: _getSectionColor(section),
      radius: widget.radius,
      child: Text(
        section,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
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

