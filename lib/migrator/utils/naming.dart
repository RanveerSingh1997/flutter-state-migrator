String toLowerCamel(String value) {
  if (value.isEmpty) return value;
  return '${value[0].toLowerCase()}${value.substring(1)}';
}

String providerNameForType(String typeName) =>
    '${toLowerCamel(typeName)}Provider';
