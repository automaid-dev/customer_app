import 'api_client.dart';

/// The backend returns HTTP 200 for almost everything, including
/// business-logic failures — it signals failure via a `status: false`
/// flag in the body, not an HTTP error code. ApiClient only converts
/// actual HTTP errors into ApiException, so every repository must check
/// `status` itself before assuming `data` is present and shaped as
/// expected. Route every `json['data']` access through this helper
/// instead of indexing directly — a raw `json['data']['x']` on a
/// status:false response (which usually has no `data` key at all) throws
/// an unhandled Dart type error instead of a catchable ApiException,
/// which silently breaks the calling screen with no visible error.
Map<String, dynamic> unwrapData(Map<String, dynamic> json, {String fallback = 'Request failed.'}) {
  if (json['status'] == false) {
    final errors =
        json['errors'] is Map<String, dynamic> ? json['errors'] as Map<String, dynamic> : null;
    throw ApiException(_describeFailure(json, errors, fallback), errors: errors);
  }
  final data = json['data'];
  if (data is Map<String, dynamic>) return data;
  return {};
}

/// Turns a Laravel-style {"field": ["reason", ...]} error bag into a
/// readable multi-line message. Falls back to the top-level `message`
/// (often just a generic "validation error") only when there's no
/// per-field detail to show instead.
String _describeFailure(Map<String, dynamic> json, Map<String, dynamic>? errors, String fallback) {
  if (errors != null && errors.isNotEmpty) {
    final lines = <String>[];
    for (final value in errors.values) {
      if (value is List) {
        lines.addAll(value.map((v) => v.toString()));
      } else if (value != null) {
        lines.add(value.toString());
      }
    }
    if (lines.isNotEmpty) return lines.join('\n');
  }
  return json['message']?.toString() ?? fallback;
}
