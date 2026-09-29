class AzkarCategory {
  final String id;
  final String name;
  final String nameEn;
  final String icon;
  final List<AzkarItem> items;

  AzkarCategory({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.icon,
    required this.items,
  });

  factory AzkarCategory.fromJson(Map<String, dynamic> json) {
    return AzkarCategory(
      id: json['id'],
      name: json['name'],
      nameEn: json['name_en'],
      icon: json['icon'],
      items: (json['items'] as List)
          .map((item) => AzkarItem.fromJson(item))
          .toList(),
    );
  }
}

class AzkarItem {
  final String text;
  final int count;
  final String reference;

  AzkarItem({
    required this.text,
    required this.count,
    required this.reference,
  });

  factory AzkarItem.fromJson(Map<String, dynamic> json) {
    return AzkarItem(
      text: json['text'],
      count: json['count'],
      reference: json['reference'],
    );
  }
}

class LiveStream {
  final String name;
  final String nameEn;
  final String url;
  final String icon;

  LiveStream({
    required this.name,
    required this.nameEn,
    required this.url,
    required this.icon,
  });

  factory LiveStream.fromJson(Map<String, dynamic> json) {
    return LiveStream(
      name: json['name'],
      nameEn: json['name_en'],
      url: json['url'],
      icon: json['icon'],
    );
  }
}
