import 'package:cf21_map_flutter/models/creator.dart';
import 'package:cf21_map_flutter/services/favorites_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.creator,
  });

  final Creator creator;

  @override
  Widget build(BuildContext context) {
    final isFavorite = context.select((FavoritesService favoritesService) => favoritesService.isFavorited(creator.id));
    final isStorageAvailable = context.select((FavoritesService favoritesService) => favoritesService.isStorageAvailable);
    final theme = Theme.of(context);

    if (!isStorageAvailable) {
      return const SizedBox.shrink();
    }
    
    return IconButton(
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? Colors.pink : theme.iconTheme.color,
      ),
      tooltip: isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
      onPressed: () async {
        if (isFavorite) {
          context.read<FavoritesService>().removeFavorite(creator.id);
        } else {
          context.read<FavoritesService>().addFavorite(creator.id);
        }
      },
    );
  }
}