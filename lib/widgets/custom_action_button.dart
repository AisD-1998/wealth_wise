import 'package:flutter/material.dart';

class CustomActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData icon;
  final bool isSmall;

  const CustomActionButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.icon,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 16,
        vertical: isSmall ? 8 : 16,
      ),
      height: isSmall ? 40 : 48,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withAlpha(40),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  onPressed == null
                      ? theme.colorScheme.surface
                      : theme.colorScheme.primary,
                  onPressed == null
                      ? theme.colorScheme.surface
                      : Color.alphaBlend(
                          theme.colorScheme.primary.withAlpha(180),
                          theme.colorScheme.secondary,
                        ),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 16 : 20,
                vertical: isSmall ? 8 : 12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: onPressed == null
                        ? theme.colorScheme.onSurface.withAlpha(128)
                        : theme.colorScheme.onPrimary,
                    size: isSmall ? 16 : 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: (isSmall
                            ? theme.textTheme.labelMedium
                            : theme.textTheme.labelLarge)
                        ?.copyWith(
                      color: onPressed == null
                          ? theme.colorScheme.onSurface.withAlpha(128)
                          : theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
