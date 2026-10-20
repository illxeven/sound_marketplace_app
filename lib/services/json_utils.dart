/// Helpers for the backend's response shapes.
///
/// List endpoints return either a plain JSON array or a page:
/// `{"items": [...], "page": 0, "size": 20, "totalElements": 57, "totalPages": 3, "hasNext": true}`.
List<dynamic> extractItems(dynamic json) {
  if (json is List) return json;
  if (json is Map && json['items'] is List) return json['items'] as List;
  if (json is Map && json['content'] is List) return json['content'] as List;
  return const [];
}

bool pageHasNext(dynamic json) => json is Map && json['hasNext'] == true;

int? asInt(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

double asDouble(dynamic v, [double fallback = 0.0]) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? fallback : fallback);

/// A page of results plus whether more pages exist.
class PageResult<T> {
  final List<T> items;
  final bool hasNext;
  final int page;

  const PageResult(this.items, {this.hasNext = false, this.page = 0});
}
