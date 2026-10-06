import 'package:flutter/material.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color color = accent ?? scheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(label.toUpperCase(), style: theme.textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: theme.textTheme.displaySmall?.copyWith(fontSize: 26),
                  ),
                  if (caption != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(caption!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
