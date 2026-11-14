import 'package:flutter/material.dart';

class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    required this.child,
    this.labelHeight,
    this.labelTrailing,
  });

  final String label;
  final Widget child;
  final double? labelHeight;
  final Widget? labelTrailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelWidget = Text(
      label,
      maxLines: labelHeight == null ? null : 2,
      overflow: labelHeight == null ? null : TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
    );
    final labelRow = Row(
      children: [
        Expanded(child: labelWidget),
        ?labelTrailing,
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelHeight == null)
          labelTrailing == null ? labelWidget : labelRow
        else
          SizedBox(
            height: labelHeight,
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: labelTrailing == null ? labelWidget : labelRow,
            ),
          ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
