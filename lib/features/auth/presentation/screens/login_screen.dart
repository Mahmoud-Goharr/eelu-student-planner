import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/errors/auth_error_mapper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../viewmodels/auth_cubit.dart';
import '../widgets/google_sign_in_button.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width >= 600 ? 32.0 : 24.0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: BlocConsumer<AuthCubit, AuthState>(
                listener: (context, state) {
                  if (state.status == AuthStatus.failure) {
                    final message = AuthErrorMapper.localized(
                      state.errorType,
                      l10n,
                    );

                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(message),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                  }
                },
                builder: (context, state) {
                  final isLoading = state.status == AuthStatus.loading;

                  return Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          AssetPaths.googleLogin,
                          width: double.infinity,
                          height: 230,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            AssetPaths.appLogo,
                            width: 42,
                            height: 42,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              l10n.appName,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.welcomeBack,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.googleLoginDescription,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 28),
                      GoogleSignInButton(
                        isLoading: isLoading,
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          context.read<AuthCubit>().signInWithGoogle();
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.studentIdAfterGoogle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
