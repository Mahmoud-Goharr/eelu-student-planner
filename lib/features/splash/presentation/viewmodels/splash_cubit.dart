import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/presentation/viewmodels/auth_cubit.dart';

enum SplashStatus { loading, ready }

class SplashState {
  const SplashState({this.status = SplashStatus.loading});

  final SplashStatus status;
}

class SplashCubit extends Cubit<SplashState> {
  SplashCubit() : super(const SplashState());

  void handleAuthState(AuthState authState) {
    if (authState.status != AuthStatus.initial &&
        authState.status != AuthStatus.loading) {
      emit(const SplashState(status: SplashStatus.ready));
    }
  }
}
