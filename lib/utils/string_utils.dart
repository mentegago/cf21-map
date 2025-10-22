String optimizeFandomFormat(String query) {
  final buffer = StringBuffer();
  for (int i = 0; i < query.length; i++) {
    final code = query.codeUnitAt(i);
    if ((code >= 48 && code <= 57) || // 0-9
        (code >= 65 && code <= 90)  || // A-Z
        (code >= 97 && code <= 122)) { // a-z
      buffer.writeCharCode(code);
    }
  }
  return buffer.toString().toLowerCase();
}

String optimizedBoothFormat(String query) {
  // Remove non-alphanumeric chars, make lower, and drop zeroes after letters (e.g. "AB08" => "ab8")
  return query
    .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
    .replaceAllMapped(
      RegExp(r'([a-zA-Z])0+'), 
      (m) => m.group(1) ?? ''
    )
    .toLowerCase();
}