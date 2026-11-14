import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.surface
        .withValues(alpha: .92);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: outline, width: size < 48 ? 1.5 : 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .14),
            blurRadius: size * .12,
            offset: Offset(0, size * .025),
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/care_center_logo.png',
        fit: BoxFit.contain,
        semanticLabel: 'CNHS Care Center Guidance and Counseling logo',
      ),
    );
  }
}
