class UrlEncoding {
  static String toUrl(Map<String, dynamic> params) {
    final base = Uri.base.removeFragment();
    if (params.isEmpty) {
      return base.toString();
    }
    final newUri = base.replace(queryParameters: params.map((k, v) => MapEntry(k, v.toString())));
    return newUri.toString();
  }
}