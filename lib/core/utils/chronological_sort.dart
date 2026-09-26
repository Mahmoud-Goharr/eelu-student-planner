/// Small shared helpers for ordering academic times consistently.
///
/// Database time columns are strings, so lexicographical sorting can put
/// `11:00` before `2:00`. These helpers compare actual clock values instead.
int compareTimeStrings(String a, String b) {
  final aMinutes = timeStringToMinutes(a);
  final bMinutes = timeStringToMinutes(b);
  return aMinutes.compareTo(bMinutes);
}

int timeStringToMinutes(String value) {
  final parts = value.trim().split(':');
  final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
  final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
  return (hour * 60) + minute;
}
