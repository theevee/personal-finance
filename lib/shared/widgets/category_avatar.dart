import 'package:flutter/material.dart';
import 'package:kabob/core/icons/app_icons.dart';

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.iconKey, required this.color, this.size = 40});

  final String iconKey;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
      child: Icon(iconFor(iconKey), color: color, size: size * 0.52),
    );
  }
}
