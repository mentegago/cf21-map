import 'package:cf21_map_flutter/models/creator.dart';
import 'package:cf21_map_flutter/services/favorites_service.dart';
import 'package:flutter/material.dart';

class FavoriteButton extends StatefulWidget {
  const FavoriteButton({
    super.key,
    required this.creator,
  });

  final Creator creator;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  final _favoritesService = FavoritesService.instance;
  bool _isFavorite = false;
  
  @override
  void initState() {
    super.initState();
    _updateFavoriteStatus();
  }

  Future<void> _updateFavoriteStatus() async {
    final isFavorite = await _favoritesService.isFavorite(widget.creator.name);
    if (mounted) {
      setState(() {
        _isFavorite = isFavorite;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStorageAvailable = _favoritesService.isStorageAvailable;
    
    // Hide the button if storage is not available
    if (!isStorageAvailable) {
      return const SizedBox.shrink();
    }
    
    return AnimatedBuilder(
      animation: _favoritesService,
      builder: (context, child) {
        _updateFavoriteStatus();
        
        return IconButton(
          icon: Icon(
            _isFavorite ? Icons.favorite : Icons.favorite_border,
            color: _isFavorite ? Colors.pink : theme.iconTheme.color,
          ),
          tooltip: _isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
          onPressed: () async {
            if (_isFavorite) {
              await _favoritesService.removeFavorite(widget.creator.name);
            } else {
              await _favoritesService.addFavorite(widget.creator);
            }
          },
        );
      },
    );
  }
}
