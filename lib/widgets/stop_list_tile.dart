import 'package:flutter/material.dart';

import '../models/stop.dart';

class StopListTile extends StatelessWidget {
  final Stop stop;
  final bool isFavourite;
  final VoidCallback onToggleFavourite;
  final VoidCallback? onTap;
  final String? trailingLabel;

  const StopListTile({
    super.key,
    required this.stop,
    required this.isFavourite,
    required this.onToggleFavourite,
    this.onTap,
    this.trailingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),

      child: InkWell(
        onTap: () {
          debugPrint(
            'STOP LIST TILE CLICKED: ${stop.name}',
          );

          if (onTap != null) {
            onTap!();
          }
        },

        child: Padding(
          padding: const EdgeInsets.all(4),

          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.location_on_outlined,
                  color: Colors.red,
                  size: 30,
                ),
              ),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                  ),

                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      Text(
                        stop.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        '${stop.lat.toStringAsFixed(4)}, '
                            '${stop.lng.toStringAsFixed(4)}',
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      const Text(
                        'Tap to view live buses',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              IconButton(
                icon: Icon(
                  isFavourite
                      ? Icons.star
                      : Icons.star_border,

                  color: isFavourite
                      ? Colors.amber
                      : null,
                ),

                onPressed: () {
                  debugPrint(
                    'FAVOURITE CLICKED: ${stop.name}',
                  );

                  onToggleFavourite();
                },
              ),

              if (trailingLabel != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    trailingLabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),

              const Padding(
                padding: EdgeInsets.only(
                  right: 10,
                ),

                child: Icon(
                  Icons.chevron_right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
