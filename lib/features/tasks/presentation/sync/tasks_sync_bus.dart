import 'dart:async';

/// Small in-process bridge between independent task screens/cubits.
/// Supabase Realtime remains the source of truth; this bus makes local
/// create/update/delete actions appear immediately in Home as well.
class TasksSyncBus {
  TasksSyncBus._();

  static final StreamController<void> _controller =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _controller.stream;

  static void notify() {
    if (!_controller.isClosed) _controller.add(null);
  }
}
