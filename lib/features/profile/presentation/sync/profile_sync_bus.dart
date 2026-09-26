import 'dart:async';

/// Notifies academic screens that the student's profile/enrollment context
/// changed. Screens can refresh their Supabase queries without restarting.
class ProfileSyncBus {
  ProfileSyncBus._();

  static final ProfileSyncBus instance = ProfileSyncBus._();

  final StreamController<void> _controller =
      StreamController<void>.broadcast();

  Stream<void> get changes => _controller.stream;

  void notify() => _controller.add(null);

  void dispose() => _controller.close();
}
