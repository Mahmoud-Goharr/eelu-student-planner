import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/auth_error_mapper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../viewmodels/auth_cubit.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/google_sign_in_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    context.read<AuthCubit>().register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  void _googleRegister() {
    FocusScope.of(context).unfocus();
    context.read<AuthCubit>().signInWithGoogle();
  }

  String? _validateName(String? value, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.requiredField;
    }

    if (value.trim().length < 2) {
      return l10n.invalidName;
    }

    return null;
  }

  String? _validateEmail(String? value, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.requiredField;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailRegex.hasMatch(value.trim())) {
      return l10n.invalidEmail;
    }

    return null;
  }

  String? _validatePassword(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) {
      return l10n.requiredField;
    }

    if (value.length < 6) {
      return l10n.passwordTooShort;
    }

    return null;
  }

  String? _validateConfirmPassword(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) {
      return l10n.confirmPasswordRequired;
    }

    if (value != _passwordController.text) {
      return l10n.passwordsDoNotMatch;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;

    final horizontalPadding = width >= 600 ? 32.0 : 24.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: BlocConsumer<AuthCubit, AuthState>(
                listener: (context, state) {
                  if (state.status == AuthStatus.failure) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            AuthErrorMapper.localized(
                              state.errorType,
                              AppLocalizations.of(context),
                            ),
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                  }
                },
                builder: (context, state) {
                  final isLoading = state.status == AuthStatus.loading;

                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: _RegisterLogo(
                            color: theme.colorScheme.primary,
                          ),
                        ),

                        const SizedBox(height: 20),

                        Center(
                          child: Text(
                            l10n.createAccount,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineSmall,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Center(
                          child: Text(
                            l10n.startOrganizing,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),

                        const SizedBox(height: 30),

                        AuthTextField(
                          controller: _nameController,
                          label: l10n.name,
                          hint: l10n.enterName,
                          prefixIcon: Icons.person_outline_rounded,
                          validator: (value) => _validateName(value, l10n),
                        ),

                        const SizedBox(height: 18),

                        AuthTextField(
                          controller: _emailController,
                          label: l10n.email,
                          hint: l10n.enterEmail,
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) => _validateEmail(value, l10n),
                        ),

                        const SizedBox(height: 18),

                        AuthTextField(
                          controller: _passwordController,
                          label: l10n.password,
                          hint: l10n.createPassword,
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePassword,
                          suffixIcon: _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          onSuffixPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          validator: (value) => _validatePassword(value, l10n),
                        ),

                        const SizedBox(height: 18),

                        AuthTextField(
                          controller: _confirmPasswordController,
                          label: l10n.confirmPassword,
                          hint: l10n.repeatPassword,
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.done,
                          suffixIcon: _obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          onSuffixPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                          validator: (value) => _validateConfirmPassword(value, l10n),
                        ),

                        const SizedBox(height: 26),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _register,
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(l10n.createAccountButton),
                          ),
                        ),

                        const SizedBox(height: 26),

                        const _OrDivider(),

                        const SizedBox(height: 26),

                        GoogleSignInButton(
                          isLoading: isLoading,
                          onPressed: _googleRegister,
                        ),

                        const SizedBox(height: 26),

                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              Text(
                                l10n.alreadyHaveAccount,
                                style: theme.textTheme.bodyMedium,
                              ),
                              GestureDetector(
                                onTap: isLoading
                                    ? null
                                    : () => context.go('/login'),
                                child: Text(
                                  l10n.login,
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _RegisterLogo extends StatelessWidget {
  const _RegisterLogo({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Icon(Icons.school_rounded, size: 36, color: color),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.or,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
