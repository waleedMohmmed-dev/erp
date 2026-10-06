import 'package:flutter/material.dart';

import 'section_card.dart';

class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    super.key,
    required this.phase,
    required this.description,
    required this.highlights,
    this.onBack,
  });

  final String phase;
  final String description;
  final List<String> highlights;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SectionCard(
      title: phase,
      subtitle: description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.hourglass_top,
                  size: 15,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 7),
                Text(
                  'غير متاح بعد',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: highlights
                .map(
                  (String highlight) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.check_circle_outline,
                          size: 15,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 7),
                        Text(highlight, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          if (onBack != null) ...<Widget>[
            const SizedBox(height: 22),
            FilledButton.tonalIcon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('العودة إلى لوحة التحكم'),
            ),
          ],
        ],
      ),
    );
  }
}
