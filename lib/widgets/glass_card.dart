import 'dart:ui';
import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double? width, height;
  final EdgeInsets? padding, margin;
  final BorderRadius? borderRadius;

  const GlassCard({
    Key? key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRad = borderRadius ?? BorderRadius.circular(24);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRad,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: width,
            height: height,
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: borderRad,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.onBackground.withOpacity(0.1),
                  theme.colorScheme.onBackground.withOpacity(0.05),
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
      ),
    );
  }
}
