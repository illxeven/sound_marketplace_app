import 'dart:convert';
import 'dart:typed_data';

class MerchandiseGroupType {
  final int id;
  final String name;
  final String? description;
  final List<MerchandiseCategory> categories;

  MerchandiseGroupType({
    required this.id,
    required this.name,
    this.description,
    this.categories = const [],
  });

  factory MerchandiseGroupType.fromJson(Map<String, dynamic> json) {
    List<MerchandiseCategory> cats = [];
    if (json['categories'] is List) {
      cats = (json['categories'] as List)
          .map((c) => MerchandiseCategory.fromJson(c as Map<String, dynamic>))
          .toList();
    }
    return MerchandiseGroupType(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      categories: cats,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'categories': categories.map((c) => c.toJson()).toList(),
    };
  }
}

class MerchandiseCategory {
  final int id;
  final String name;
  final int? groupTypeId;
  final String? groupTypeName;
  final String? groupTypeDescription;

  MerchandiseCategory({
    required this.id,
    required this.name,
    this.groupTypeId,
    this.groupTypeName,
    this.groupTypeDescription,
  });

  factory MerchandiseCategory.fromJson(Map<String, dynamic> json) {
    return MerchandiseCategory(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      groupTypeId: (json['groupTypeId'] as num?)?.toInt(),
      groupTypeName: json['groupTypeName'] as String?,
      groupTypeDescription: json['groupTypeDescription'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'groupTypeId': groupTypeId,
      'groupTypeName': groupTypeName,
      'groupTypeDescription': groupTypeDescription,
    };
  }
}

class MerchandiseType {
  final int id;
  final String typeName;

  MerchandiseType({
    required this.id,
    required this.typeName,
  });

  factory MerchandiseType.fromJson(Map<String, dynamic> json) {
    return MerchandiseType(
      id: (json['id'] as num).toInt(),
      typeName: json['typeName'] as String? ?? 'Sample Pack',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'typeName': typeName,
    };
  }
}

class Merchandise {
  final int id;
  final int? merchandiseTypeId;
  final String? merchandiseTypeName;
  final int? categoryId;
  final String? categoryName;
  final int? groupTypeId;
  final String? groupTypeName;
  final int? sellerId;
  final String? sellerEmail;
  final String title;
  final double price;
  final String? description;
  final String? filePath;
  final String? coverImageUrl;
  final Uint8List? imageBlob;
  final Uint8List? imageBlob2;
  final Uint8List? imageBlob3;
  final Uint8List? imageBlob4;
  final Uint8List? imageBlob5;
  final String? options;
  final int stockQuantity;
  final int quantity;
  final double? averageRating;
  final int reviewCount;
  final DateTime? createdAt;

  Merchandise({
    required this.id,
    this.merchandiseTypeId,
    this.merchandiseTypeName,
    this.categoryId,
    this.categoryName,
    this.groupTypeId,
    this.groupTypeName,
    this.sellerId,
    this.sellerEmail,
    required this.title,
    this.price = 0.0,
    this.description,
    this.filePath,
    this.coverImageUrl,
    this.imageBlob,
    this.imageBlob2,
    this.imageBlob3,
    this.imageBlob4,
    this.imageBlob5,
    this.options,
    this.stockQuantity = 10,
    int? quantity,
    this.averageRating,
    this.reviewCount = 0,
    this.createdAt,
  }) : quantity = quantity ?? stockQuantity;

  List<Uint8List> get allImages {
    final list = <Uint8List>[];
    if (imageBlob != null) list.add(imageBlob!);
    if (imageBlob2 != null) list.add(imageBlob2!);
    if (imageBlob3 != null) list.add(imageBlob3!);
    if (imageBlob4 != null) list.add(imageBlob4!);
    if (imageBlob5 != null) list.add(imageBlob5!);
    return list;
  }

  String get sellerDisplay =>
      sellerEmail != null ? sellerEmail!.split('@').first : 'Seller #$sellerId';

  String get displayCategory =>
      categoryName ?? merchandiseTypeName ?? 'Merchandise';

  bool get isOutOfStock => stockQuantity <= 0;

  Merchandise copyWith({
    int? id,
    int? merchandiseTypeId,
    String? merchandiseTypeName,
    int? categoryId,
    String? categoryName,
    int? groupTypeId,
    String? groupTypeName,
    int? sellerId,
    String? sellerEmail,
    String? title,
    double? price,
    String? description,
    String? filePath,
    String? coverImageUrl,
    Uint8List? imageBlob,
    Uint8List? imageBlob2,
    Uint8List? imageBlob3,
    Uint8List? imageBlob4,
    Uint8List? imageBlob5,
    String? options,
    int? stockQuantity,
    int? quantity,
    double? averageRating,
    int? reviewCount,
    DateTime? createdAt,
  }) {
    return Merchandise(
      id: id ?? this.id,
      merchandiseTypeId: merchandiseTypeId ?? this.merchandiseTypeId,
      merchandiseTypeName: merchandiseTypeName ?? this.merchandiseTypeName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      groupTypeId: groupTypeId ?? this.groupTypeId,
      groupTypeName: groupTypeName ?? this.groupTypeName,
      sellerId: sellerId ?? this.sellerId,
      sellerEmail: sellerEmail ?? this.sellerEmail,
      title: title ?? this.title,
      price: price ?? this.price,
      description: description ?? this.description,
      filePath: filePath ?? this.filePath,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      imageBlob: imageBlob ?? this.imageBlob,
      imageBlob2: imageBlob2 ?? this.imageBlob2,
      imageBlob3: imageBlob3 ?? this.imageBlob3,
      imageBlob4: imageBlob4 ?? this.imageBlob4,
      imageBlob5: imageBlob5 ?? this.imageBlob5,
      options: options ?? this.options,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      quantity: quantity ?? this.quantity,
      averageRating: averageRating ?? this.averageRating,
      reviewCount: reviewCount ?? this.reviewCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static Uint8List? _parseBlob(dynamic val) {
    if (val == null) return null;
    if (val is Uint8List) return val;
    if (val is List<int>) return Uint8List.fromList(val);
    if (val is List) {
      try {
        return Uint8List.fromList(val.map((e) => (e as num).toInt()).toList());
      } catch (_) {}
    }
    if (val is String && val.isNotEmpty) {
      try {
        String clean = val;
        if (clean.contains(',')) {
          clean = clean.split(',').last;
        }
        return base64Decode(clean);
      } catch (_) {}
    }
    return null;
  }

  factory Merchandise.fromJson(Map<String, dynamic> json) {
    final stock = (json['quantity'] as num?)?.toInt() ??
        (json['stockQuantity'] as num?)?.toInt() ??
        10;
    return Merchandise(
      id: (json['id'] as num).toInt(),
      merchandiseTypeId: (json['merchandiseTypeId'] as num?)?.toInt(),
      merchandiseTypeName: json['merchandiseTypeName'] as String? ?? json['typeName'] as String?,
      categoryId: (json['categoryId'] as num?)?.toInt(),
      categoryName: json['categoryName'] as String?,
      groupTypeId: (json['groupTypeId'] as num?)?.toInt(),
      groupTypeName: json['groupTypeName'] as String?,
      sellerId: (json['sellerId'] as num?)?.toInt(),
      sellerEmail: json['sellerEmail'] as String? ?? json['sellerName'] as String?,
      title: json['title'] as String? ?? 'Sound Pack',
      price: (json['price'] != null) ? (json['price'] as num).toDouble() : 0.0,
      description: json['description'] as String?,
      filePath: json['filePath'] as String?,
      coverImageUrl: json['coverImageUrl'] as String? ??
          json['coverUrl'] as String? ??
          (json['id'] != null ? '/merchandise/${json['id']}/images/1' : null),
      imageBlob: _parseBlob(json['image_blob'] ?? json['imageBlob']),
      imageBlob2: _parseBlob(json['image_blob_2'] ?? json['imageBlob2']),
      imageBlob3: _parseBlob(json['image_blob_3'] ?? json['imageBlob3']),
      imageBlob4: _parseBlob(json['image_blob_4'] ?? json['imageBlob4']),
      imageBlob5: _parseBlob(json['image_blob_5'] ?? json['imageBlob5']),
      options: json['options'] as String?,
      stockQuantity: stock,
      quantity: stock,
      averageRating: (json['averageRating'] != null) ? (json['averageRating'] as num).toDouble() : null,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchandiseTypeId': merchandiseTypeId,
      'merchandiseTypeName': merchandiseTypeName,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'groupTypeId': groupTypeId,
      'groupTypeName': groupTypeName,
      'sellerId': sellerId,
      'sellerEmail': sellerEmail,
      'title': title,
      'price': price,
      'description': description,
      'filePath': filePath,
      'imageBlob': imageBlob != null ? base64Encode(imageBlob!) : null,
      'imageBlob2': imageBlob2 != null ? base64Encode(imageBlob2!) : null,
      'imageBlob3': imageBlob3 != null ? base64Encode(imageBlob3!) : null,
      'imageBlob4': imageBlob4 != null ? base64Encode(imageBlob4!) : null,
      'imageBlob5': imageBlob5 != null ? base64Encode(imageBlob5!) : null,
      'options': options,
      'stockQuantity': stockQuantity,
      'quantity': quantity,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
