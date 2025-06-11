import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width, height;
  final EdgeInsets? padding, margin;
  final BorderRadius? borderRadius;
  final bool lightened; // New parameter

  const GlassCard({
    Key? key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.lightened = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRad = borderRadius ?? BorderRadius.circular(24);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRad,
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: lightened ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.1),
            borderRadius: borderRad,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.onBackground.withOpacity(0.10),
                theme.colorScheme.onBackground.withOpacity(0.01),
              ],
            ),
            border: Border.all(
              color: theme.colorScheme.onBackground.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}