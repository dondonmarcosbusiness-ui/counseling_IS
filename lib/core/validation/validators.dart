String? requiredField(String? value, [String label = 'This field']) {
  if (value == null || value.trim().isEmpty) return '$label is required';
  return null;
}

String? minLength(String? value, int min, [String label = 'Value']) {
  if (value == null || value.length < min) {
    return '$label must be at least $min characters';
  }
  return null;
}

String? username(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Username is required';
  if (v.length < 3 || v.length > 32) {
    return 'Username must be 3-32 characters';
  }
  if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(v)) {
    return 'Username may only contain letters, digits, _ and .';
  }
  return null;
}

String? passwordStrength(String? value) {
  if (value == null || value.isEmpty) return 'Password is required';
  if (value.length < 10) return 'Password must be at least 10 characters';
  if (!value.contains(RegExp(r'[a-z]'))) {
    return 'Password must contain a lowercase letter';
  }
  if (!value.contains(RegExp(r'[A-Z]'))) {
    return 'Password must contain an uppercase letter';
  }
  if (!value.contains(RegExp(r'[0-9]'))) {
    return 'Password must contain a digit';
  }
  return null;
}

String? optionalEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
    return 'Enter a valid email address';
  }
  return null;
}

String? optionalPhone(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  if (!RegExp(r'^[0-9+\-() \s]{5,20}$').hasMatch(v)) {
    return 'Enter a valid phone number';
  }
  return null;
}

String? sameAs(String? value, String? other, [String label = 'Passwords']) {
  if (value != other) return '$label do not match';
  return null;
}
