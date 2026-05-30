/// Converts the first character of [value] to lower-case, leaving the rest unchanged.
///
/// Returns [value] unchanged when it is empty.
String toLowerCamel(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toLowerCase()}${value.substring(1)}';
}

/// Returns the conventional Riverpod provider variable name for [typeName].
///
/// Example: `Counter` → `counterProvider`.
String providerNameForType(String typeName) =>
    '${toLowerCamel(typeName)}Provider';
