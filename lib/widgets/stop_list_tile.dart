import 'package:flutter/material.dart';

import '../models/stop.dart';

class StopListTile extends StatelessWidget {
  final Stop stop;
  final bool isFavourite;
  final VoidCallback onToggleFavourite;
  final VoidCallback? onTap;

  const StopListTile({
    super.key,
    required this.stop,
    required this.isFavourite,
    required this.onToggleFavourite,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.location_on_outlined),
        title: Text(stop.name),
        subtitle: Text('${stop.lat.toStringAsFixed(4)}, '
            '${stop.lng.toStringAsFixed(4)}'),
        trailing: IconButton(
          icon: Icon(
            isFavourite ? Icons.star : Icons.star_border,
            color: isFavourite ? Colors.amber : null,
          ),
          onPressed: onToggleFavourite,
        ),
      ),
    );
  }
}
