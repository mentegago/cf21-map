import 'package:cached_network_image/cached_network_image.dart';
import 'package:cf21_map_flutter/widgets/favorite_button.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../models/creator.dart';
import '../utils/url_encoding.dart';

class CreatorDetailContent extends StatelessWidget {
  final Creator creator;
  final bool showFavoriteButton;
  final bool showShareButton;
  final bool showCloseButton;
  final VoidCallback? onClose;
  final Function(String) onRequestSearch;

  const CreatorDetailContent({
    super.key,
    required this.creator,
    this.showFavoriteButton = false,
    this.showShareButton = true,
    this.showCloseButton = false,
    this.onClose,
    required this.onRequestSearch,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _headerSection(context),
          const SizedBox(height: 16),
          
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
                return ActionChip(
                  avatar: const Icon(Icons.favorite, size: 18),
                  label: Text(fandom),
                  onPressed: () {
                    onRequestSearch(fandom);
                  },
                  backgroundColor: theme.colorScheme.primaryContainer,
                  side: BorderSide(color: theme.colorScheme.primary),
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

          const SizedBox(height: 32)
        ],
      ),
    );
  }

  ClipRRect _headerSection(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              _CircleCut(creator: creator),
              Positioned(
                top: 0,
                right: 0,
                child: Row(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.8),
                        borderRadius: const BorderRadius.all(Radius.circular(32)),
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          if (showFavoriteButton) 
                            FavoriteButton(
                              key: Key(creator.name), 
                              creator: creator
                            ),
                          if (showShareButton)
                            IconButton(
                              icon: const Icon(Icons.share),
                              tooltip: 'Share',
                              onPressed: () => _shareCreator(context),
                            ),
                        ],
                      ),
                    ),
                    if (showCloseButton && onClose != null)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: const BorderRadius.all(Radius.circular(32)),
                          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                          onPressed: onClose,
                        ),
                      ),
                  ],
                ),
              )
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  creator.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            
                const SizedBox(height: 4),
            
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
              ],
            ),
          ),
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
      final shareUrl = UrlEncoding.toUrl({'creator_id': creator.id});
      
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

class _CircleCut extends StatefulWidget {
  final Creator creator;

  const _CircleCut({required this.creator});

  @override
  State<_CircleCut> createState() => _CircleCutState();
}

class _CircleCutState extends State<_CircleCut> {

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    return AspectRatio(
      aspectRatio: isDesktop ? 0.8 : 2.0,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: ClipRect(
          child: Transform.scale(
            scale: isDesktop ? 1.3 : 1.1,
            alignment: Alignment.bottomCenter,
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