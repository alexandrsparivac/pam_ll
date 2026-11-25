Map<String, dynamic> jsonObject(Object? value, String field) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('Expected object: $field');
  }
  return Map<String, dynamic>.from(value);
}

List<dynamic> jsonList(Object? value, String field) {
  if (value == null) return [];
  if (value is! List) throw FormatException('Expected list: $field');
  return value;
}

String jsonString(Object? value, String field, {bool required = false}) {
  if (value == null && !required) return '';
  if (value is! String || (required && value.trim().isEmpty)) {
    throw FormatException('Expected text: $field');
  }
  return value;
}

double jsonNumber(Object? value, String field, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is! num || !value.isFinite || value < 0) {
    throw FormatException('Invalid number: $field');
  }
  return value.toDouble();
}

int jsonInteger(Object? value, String field) {
  final number = jsonNumber(value, field);
  if (number != number.roundToDouble()) {
    throw FormatException('Invalid integer: $field');
  }
  return number.toInt();
}

bool jsonBool(Object? value, String field, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is! bool) throw FormatException('Expected boolean: $field');
  return value;
}
