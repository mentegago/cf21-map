import 'package:cf21_map_flutter/widgets/favorite_button.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../models/creator.dart';
import 'creator_avatar.dart';

class CreatorDetailContent extends StatelessWidget {
  final Creator creator;
  final bool showFavoriteButton;
  final bool showShareButton;
  final bool showCloseButton;
  final VoidCallback? onClose;

  const CreatorDetailContent({
    super.key,
    required this.creator,
    this.showFavoriteButton = false,
    this.showShareButton = true,
    this.showCloseButton = false,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              CreatorAvatar(creator: creator),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      creator.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      creator.boothsDisplay,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (showFavoriteButton) FavoriteButton(key: Key(creator.name), creator: creator),
              if (showShareButton)
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Share',
                  onPressed: () => _shareCreator(context),
                ),
              if (showCloseButton && onClose != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: onClose,
                ),
            ],
          ),

          const SizedBox(height: 8),

          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Circle Page'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              elevation: 0,
            ),
            onPressed: () {
              final url = 'https://catalog.comifuro.net/circle/${creator.id}';
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
          ),
    
          const SizedBox(height: 16),
          const Divider(),
    
          // Event day
          Row(
            children: [
              Icon(Icons.calendar_today, color: _getDayColor(creator.day), size: 20),
              const SizedBox(width: 8),
              Text(
                creator.dayDisplay,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getDayColor(creator.day),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
    
          // Informations
          ...creator.informations.map((info) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  info.content,
                  style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: 16),
              ],
            );
          }),
    
          // URLs
          if (creator.urls.isNotEmpty) ...[
            const Text(
              'Links',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: creator.urls.map((link) {
                return Tooltip(
                  message: link.url,
                  child: ActionChip(
                    avatar: const Icon(Icons.link, size: 18),
                    label: Text(link.title.isNotEmpty ? link.title : link.url),
                    onPressed: () {
                      try {
                        launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    },
                    backgroundColor: theme.colorScheme.primaryContainer,
                    side: BorderSide(color: theme.colorScheme.primary),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
          ],

          // Fandom
          if (creator.fandoms.isNotEmpty) ...[
            Text(
              'Fandom${creator.fandoms.length > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: creator.fandoms.map((fandom) {
                return Chip(
                  avatar: Icon(Icons.favorite, size: 18, color: theme.colorScheme.primary),
                  label: Text(fandom),
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
          ],

          // Works Type
          if (creator.worksType.isNotEmpty) ...[
            Text(
              'Works Type${creator.worksType.length > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: creator.worksType.map((worksType) {
                return Chip(
                  avatar: Icon(Icons.sell, size: 18, color: theme.colorScheme.primary),
                  label: Text(worksType),
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
          ],
    
          // Booths
          Text(
            'Booth Location${creator.booths.length > 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: creator.booths.map((booth) {
              return Chip(
                avatar: Icon(Icons.location_on, size: 18, color: theme.colorScheme.primary),
                label: Text(booth),
                backgroundColor: theme.colorScheme.surfaceContainerLow,
              );
            }).toList(),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Color _getDayColor(String day) {
    switch (day) {
      case 'BOTH':
        return Colors.purple;
      case 'SAT':
        return Colors.blue;
      case 'SUN':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _shareCreator(BuildContext context) async {
    try {
      final shareUrl = 'https://cf21.nnt.gg/?creator_id=${creator.id}';
      
      await Clipboard.setData(ClipboardData(text: shareUrl));

      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Link copied: ${creator.name}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not copy link.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
