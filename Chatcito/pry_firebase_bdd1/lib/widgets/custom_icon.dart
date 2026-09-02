import 'package:flutter/material.dart';
import '../themes/app_colors.dart';

class CustomIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;

  const CustomIcon({
    super.key,
    required this.icon,
    this.size = 30,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color,
    );
  }
}