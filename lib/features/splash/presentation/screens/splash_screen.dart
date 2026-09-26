import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/presentation/viewmodels/auth_cubit.dart';
import '../viewmodels/splash_cubit.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<SplashCubit>().handleAuthState(
            context.read<AuthCubit>().state,
          );
    });
  }

  void _goToAuthRoute(AuthState state) {
    if (!mounted) {
      return;
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }

      context.go(
        state.status == AuthStatus.authenticated ? '/home' : '/',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        context.read<SplashCubit>().handleAuthState(state);
      },
      child: BlocListener<SplashCubit, SplashState>(
        listener: (context, state) {
          if (state.status == SplashStatus.ready) {
            _goToAuthRoute(context.read<AuthCubit>().state);
          }
        },
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      AssetPaths.appLogo,
                      width: 150,
                      height: 150,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.appName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.appTagline,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
