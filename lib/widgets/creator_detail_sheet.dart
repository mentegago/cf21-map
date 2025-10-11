import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../models/creator.dart';
import 'creator_avatar.dart';

class CreatorDetailSheet extends StatelessWidget {
  final Creator creator;
  final VoidCallback onClose;

  const CreatorDetailSheet({
    super.key,
    required this.creator,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.25,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              // Compact header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(
                  children: [
                    CreatorAvatar(creator: creator),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            creator.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            creator.boothsDisplay,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share),
                      tooltip: 'Share',
                      onPressed: () => _shareCreator(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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

                        // Informations (optional) - each as its own section
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

                        // URLs (optional)
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
                              return ActionChip(
                                avatar: const Icon(Icons.link, size: 18, weight: 1.5,),
                                label: Text(link.title.isNotEmpty ? link.title : link.url),
                                onPressed: () {
                                  try {
                                    launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication);
                                  } catch (_) {}
                                },
                                backgroundColor: theme.colorScheme.primaryContainer,
                                side: BorderSide(color: theme.colorScheme.primary),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Booths section
                        Text(
                          'Booth Location${creator.booths.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // Booth chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: creator.booths.map((booth) {
                            return Chip(
                              avatar: Icon(Icons.location_on, size: 18, color: theme.colorScheme.primary),
                              label: Text(
                                booth,
                              ),
                              backgroundColor: theme.colorScheme.surfaceContainerLow,
                            );
                          }).toList(),
                        ),
                        
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
      final encodedName = Uri.encodeComponent(creator.name).toLowerCase();
      final shareUrl = 'https://cf21.nnt.gg/?creator=$encodedName';
      
      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: shareUrl));

      if(!context.mounted) return;
      
      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Link copied: ${creator.name}'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Fallback: show the URL in a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not copy link. Please copy manually from the URL bar.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

