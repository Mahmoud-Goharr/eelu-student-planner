import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/errors/auth_error_mapper.dart';
import '../../../../core/localization/app_localizations.dart';
import '../viewmodels/auth_cubit.dart';

class StudentIdScreen extends StatefulWidget {
  const StudentIdScreen({super.key});

  @override
  State<StudentIdScreen> createState() => _StudentIdScreenState();
}

class _StudentIdScreenState extends State<StudentIdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();


  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    context.read<AuthCubit>().completeStudentProfile(
      studentId: _studentIdController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: BlocConsumer<AuthCubit, AuthState>(
                listener: (context, state) {
                  if (state.status == AuthStatus.needsStudentId &&
                      state.errorType != null) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(
                            AuthErrorMapper.localized(state.errorType, l10n),
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                  }
                },
                builder: (context, state) {
                  final loading = state.status == AuthStatus.loading;

                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            AssetPaths.studentIdLogin,
                            width: double.infinity,
                            height: 230,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l10n.completeProfile,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.studentIdDescription,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _studentIdController,
                          enabled: !loading,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: l10n.studentId,
                            hintText: l10n.studentIdHint,
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                          validator: (value) {
                            if ((value?.trim() ?? '').length < 3) {
                              return l10n.invalidStudentId;
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: loading ? null : _submit,
                            child: loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(l10n.continueLabel),
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
