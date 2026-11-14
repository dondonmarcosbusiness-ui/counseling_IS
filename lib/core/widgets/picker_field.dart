import 'package:flutter/material.dart';

/// Field-styled button used to pick dates and times from dialogs.
/// Mirrors the look of the text inputs so forms stay visually consistent.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.displayValue,
    required this.icon,
    required this.onTap,
    this.errorText,
    this.onClear,
    this.enabled = true,
    this.height = 48,
    this.labelHeight,
  });

  final String label;
  final String displayValue;
  final IconData icon;
  final VoidCallback onTap;
  final String? errorText;
  final VoidCallback? onClear;
  final bool enabled;
  final double height;
  final double? labelHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasError = errorText != null;
    final labelWidget = Text(
      label,
      maxLines: labelHeight == null ? null : 2,
      overflow: labelHeight == null ? null : TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelHeight == null)
          labelWidget
        else
          SizedBox(
            height: labelHeight,
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: labelWidget,
            ),
          ),
        const SizedBox(height: 6),
        Material(
          color: enabled ? scheme.surfaceContainerLowest : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: hasError
                  ? scheme.error
                  : enabled
                  ? scheme.outlineVariant
                  : scheme.outlineVariant.withValues(alpha: .6),
              width: hasError ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: enabled ? onTap : null,
            hoverColor: scheme.primaryContainer.withValues(alpha: .35),
            splashColor: scheme.primary.withValues(alpha: .08),
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, size: 18, color: scheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayValue,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (onClear != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        onPressed: enabled ? onClear : null,
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear',
                      )
                    else
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: scheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              errorText!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.error),
            ),
          ),
      ],
    );
  }
}
