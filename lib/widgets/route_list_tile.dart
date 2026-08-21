import 'package:flutter/material.dart';

import '../models/route_model.dart';

class RouteListTile extends StatelessWidget {
  final TransitRoute route;
  final bool isFavourite;
  final VoidCallback onToggleFavourite;
  final VoidCallback? onTap;
  final String? trailingLabel;

  const RouteListTile({
    super.key,
    required this.route,
    required this.isFavourite,
    required this.onToggleFavourite,
    this.onTap,
    this.trailingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            route.shortName.isNotEmpty
                ? route.shortName.substring(
                0, route.shortName.length > 4 ? 4 : route.shortName.length)
                : '?',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        title: Text(
          route.shortName.isNotEmpty ? route.shortName : route.longName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: route.longName.isNotEmpty && route.shortName.isNotEmpty
            ? Text(route.longName, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingLabel != null) ...[
              Text(trailingLabel!, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 4),
            ],
            IconButton(
              icon: Icon(
                isFavourite ? Icons.star : Icons.star_border,
                color: isFavourite ? Colors.amber : null,
              ),
              onPressed: onToggleFavourite,
            ),
          ],
        ),
      ),
    );
  }
}