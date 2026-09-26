import 'package:flutter/material.dart';

import 'app_shimmer.dart';

class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    this.width,
    required this.height,
    this.radius = 12,
    super.key,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
