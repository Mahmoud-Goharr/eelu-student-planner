import 'package:flutter/material.dart';

import '../../../../core/widgets/shimmer/shimmer_card.dart';

class NotificationSkeleton extends StatelessWidget {
  const NotificationSkeleton({super.key});
  @override
  Widget build(BuildContext context) =>
      const ShimmerCard(height: 104, margin: EdgeInsets.only(bottom: 12));
}
