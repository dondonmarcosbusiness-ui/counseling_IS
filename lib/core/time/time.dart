String nowUtcIso() => dateTimeToDb(DateTime.now());

String dateTimeToDb(DateTime value) {
  final truncated =
      DateTime.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch,
          isUtc: true);
  return truncated.toIso8601String();
}

DateTime? parseDbDateTime(String? value) =>
    value == null ? null : DateTime.tryParse(value)?.toLocal();

String dateToDb(DateTime value) {
  final y = value.year.toString().padLeft(4, '0');
  final m = value.month.toString().padLeft(2, '0');
  final d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime? parseDbDate(String? value) {
  if (value == null) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}
