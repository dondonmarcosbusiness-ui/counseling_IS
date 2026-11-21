import 'package:flutter/material.dart';

/// Inline confirmation shown after a successful save. Styled to match
/// `ErrorBanner` so success and failure read as one system: a tinted
/// container, an icon, and an optional dismiss action.
class SuccessBanner extends StatelessWidget {
  const SuccessBanner({super.key, required this.message, this.onDismiss});

  final String message;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                message,
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close, size: 16),
              color: scheme.onPrimaryContainer,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}
