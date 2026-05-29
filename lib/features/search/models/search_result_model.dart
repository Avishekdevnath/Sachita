class SearchResultModel {
  const SearchResultModel({
    required this.id,
    required this.source,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.parentId,
  });

  final String id;
  final String source;
  final String kind;
  final String title;
  final String subtitle;
  final String? parentId;
}
