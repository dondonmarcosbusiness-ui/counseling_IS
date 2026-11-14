const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// e.g. `Mar 5, 2026`
String formatDate(DateTime value) =>
    '${_months[value.month - 1]} ${value.day}, ${value.year}';

/// e.g. `09:05`
String formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// e.g. `Mar 5, 2026, 09:05`
String formatDateTime(DateTime value) =>
    '${formatDate(value)}, ${formatTime(value)}';
