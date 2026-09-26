class Failure implements Exception {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}
