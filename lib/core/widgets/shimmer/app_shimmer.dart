import 'package:flutter/material.dart';

class AppShimmer extends StatefulWidget {
  const AppShimmer({required this.child, super.key});

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.onSurface.withValues(
      alpha: theme.brightness == Brightness.dark ? .12 : .08,
    );
    final highlight = theme.colorScheme.onSurface.withValues(
      alpha: theme.brightness == Brightness.dark ? .22 : .16,
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final offset = (_controller.value * 2) - 1;
          return LinearGradient(
            begin: Alignment(offset - 1, 0),
            end: Alignment(offset + 1, 0),
            colors: [base, highlight, base],
            stops: const [0.25, 0.5, 0.75],
          ).createShader(bounds);
        },
        child: child,
      ),
      child: widget.child,
    );
  }
}
