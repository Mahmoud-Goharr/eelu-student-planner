import 'dart:async';

class NotificationsSyncBus {
  NotificationsSyncBus._();

  static final NotificationsSyncBus instance = NotificationsSyncBus._();

  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notifyChanged() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  void dispose() {
    _controller.close();
  }
}
