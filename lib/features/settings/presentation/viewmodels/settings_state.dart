class SettingsState {
  const SettingsState({this.notificationsEnabled = true});

  final bool notificationsEnabled;

  SettingsState copyWith({bool? notificationsEnabled}) {
    return SettingsState(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }
}
