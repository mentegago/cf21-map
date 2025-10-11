import 'package:flutter/material.dart';
import '../models/creator.dart';

class CreatorSelectorSheet extends StatelessWidget {
  final String boothId;
  final List<Creator> creators;
  final Function(Creator) onCreatorSelected;

  const CreatorSelectorSheet({
    super.key,
    required this.boothId,
    required this.creators,
    required this.onCreatorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Select Creator',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Booth $boothId',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // Creator list (Saturday first, then Sunday, then Both/others)
          ListView.builder(
            shrinkWrap: true,
            itemCount: creators.length,
            itemBuilder: (context, index) {
              final sorted = [...creators]..sort((a, b) {
                int rank(String day) {
                  switch (day.toUpperCase()) {
                    case 'SAT':
                      return 0;
                    case 'SUN':
                      return 1;
                    case 'BOTH':
                      return 2;
                    default:
                      return 3;
                  }
                }
                final r = rank(a.day).compareTo(rank(b.day));
                if (r != 0) return r;
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });
              final creator = sorted[index];
              final section = _getBoothSection(creator);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getSectionColor(section),
                  child: Text(
                    section,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  creator.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  creator.dayDisplay,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () {
                  Navigator.pop(context);
                  onCreatorSelected(creator);
                },
              );
            },
          ),
          
          const SizedBox(height: 16),
        ],
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
    final List<Color> palette = const [
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

