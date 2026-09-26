import 'package:flutter/material.dart';

import '../../../../core/widgets/shimmer/shimmer_card.dart';

class LectureSkeleton extends StatelessWidget {
  const LectureSkeleton({super.key});
  @override
  Widget build(BuildContext context) =>
      const ShimmerCard(height: 112, margin: EdgeInsets.only(bottom: 12));
}
