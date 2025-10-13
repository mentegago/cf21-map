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
  bool _isFavorite = false;
  
  @override
  void initState() {
    super.initState();
    FavoritesService.instance.isFavorite(widget.creator.name).then((isFavorite) {
      setState(() {
        _isFavorite = isFavorite;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      icon: Icon(
        _isFavorite ? Icons.favorite : Icons.favorite_border,
        color: _isFavorite ? Colors.pink : theme.iconTheme.color,
      ),
      tooltip: _isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
      onPressed: () async {
        if (_isFavorite) {
          await FavoritesService.instance.removeFavorite(widget.creator.name);
          setState(() {
            _isFavorite = false;
          });
        } else {
          await FavoritesService.instance.addFavorite(widget.creator);
          setState(() {
            _isFavorite = true;
          });
        }
      },
    );
  }
}
