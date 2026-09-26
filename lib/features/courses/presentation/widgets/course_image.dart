import 'package:flutter/material.dart';

class CourseImage extends StatelessWidget {
  const CourseImage({
    super.key,
    required this.url,
    this.size,
    this.fallback,
  });

  final String? url;
  final double? size;
  final IconData? fallback;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim();
    final icon = fallback ?? Icons.menu_book_outlined;
    final box = size ?? double.infinity;

    return Container(
      width: box,
      height: size ?? 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: imageUrl == null || imageUrl.isEmpty
          ? Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary)
          : ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                width: box,
                height: size ?? 120,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Icon(
                  icon,
                  size: 34,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
    );
  }
}
