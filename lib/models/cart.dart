import 'dart:convert';
import 'dart:typed_data';

class CartItem {
  final int id;
  final int cartId;
  final String itemType; // 'MERCHANDISE' or 'TRACK'

  // Merchandise info
  final int? merchandiseId;
  final String? merchandiseTitle;
  final String? merchandiseCategory;
  final String? merchandiseImageUrl;
  final Uint8List? merchandiseImageBlob;

  // Track info
  final int? trackId;
  final String? trackTitle;
  final String? trackArtist;
  final String? trackCoverUrl;
  final Uint8List? trackCoverBlob;

  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final DateTime? addedAt;

  CartItem({
    required this.id,
    required this.cartId,
    required this.itemType,
    this.merchandiseId,
    this.merchandiseTitle,
    this.merchandiseCategory,
    this.merchandiseImageUrl,
    this.merchandiseImageBlob,
    this.trackId,
    this.trackTitle,
    this.trackArtist,
    this.trackCoverUrl,
    this.trackCoverBlob,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.addedAt,
  });

  String get displayTitle =>
      itemType == 'MERCHANDISE' ? (merchandiseTitle ?? 'Merchandise') : (trackTitle ?? 'Track');

  String get displaySubtitle =>
      itemType == 'MERCHANDISE' ? (merchandiseCategory ?? 'Product') : (trackArtist ?? 'Audio Single');

  bool get isMerchandise => itemType == 'MERCHANDISE';
  bool get isTrack => itemType == 'TRACK';

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: (json['id'] as num).toInt(),
      cartId: (json['cartId'] as num).toInt(),
      itemType: json['itemType'] as String? ?? 'MERCHANDISE',
      merchandiseId: (json['merchandiseId'] as num?)?.toInt(),
      merchandiseTitle: json['merchandiseTitle'] as String?,
      merchandiseCategory: json['merchandiseCategory'] as String?,
      merchandiseImageUrl: json['merchandiseImageUrl'] as String?,
      merchandiseImageBlob: json['merchandiseImageBlob'] != null
          ? (json['merchandiseImageBlob'] is String
              ? base64Decode(json['merchandiseImageBlob'])
              : Uint8List.fromList(List<int>.from(json['merchandiseImageBlob'])))
          : null,
      trackId: (json['trackId'] as num?)?.toInt(),
      trackTitle: json['trackTitle'] as String?,
      trackArtist: json['trackArtist'] as String?,
      trackCoverUrl: json['trackCoverUrl'] as String?,
      trackCoverBlob: json['trackCoverBlob'] != null
          ? (json['trackCoverBlob'] is String
              ? base64Decode(json['trackCoverBlob'])
              : Uint8List.fromList(List<int>.from(json['trackCoverBlob'])))
          : null,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      addedAt: json['addedAt'] != null ? DateTime.tryParse(json['addedAt'].toString()) : null,
    );
  }
}

class Cart {
  final int id;
  final int userId;
  final List<CartItem> items;
  final int totalItems;
  final double subtotal;

  Cart({
    required this.id,
    required this.userId,
    this.items = const [],
    this.totalItems = 0,
    this.subtotal = 0.0,
  });

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  factory Cart.fromJson(Map<String, dynamic> json) {
    List<CartItem> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((i) => CartItem.fromJson(i as Map<String, dynamic>))
          .toList();
    }
    return Cart(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      items: parsedItems,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? parsedItems.length,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
