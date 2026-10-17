import 'dart:convert';
import 'dart:typed_data';
import '../models/merchandise.dart';
import '../models/merchandise_review.dart';
import '../models/payment_history.dart';
import 'api_client.dart';

class MarketplaceService {
  Future<List<Merchandise>> getAllMerchandise() async {
    final response = await ApiClient.get<List<Merchandise>>(
      '/merchandise',
      fromJsonT: (json) {
        if (json is List) {
          return json.map((i) => Merchandise.fromJson(i as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<Merchandise?> getMerchandiseById(int id) async {
    final response = await ApiClient.get<Merchandise>(
      '/merchandise/$id',
      fromJsonT: (json) => Merchandise.fromJson(json as Map<String, dynamic>),
    );
    return response.data;
  }

  Future<List<Merchandise>> getMerchandiseBySeller(int sellerId) async {
    final response = await ApiClient.get<List<Merchandise>>(
      '/merchandise/seller/$sellerId',
      fromJsonT: (json) {
        if (json is List) {
          return json.map((i) => Merchandise.fromJson(i as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<List<MerchandiseType>> getMerchandiseTypes() async {
    final response = await ApiClient.get<List<MerchandiseType>>(
      '/merchandise/types',
      fromJsonT: (json) {
        if (json is List) {
          return json.map((i) => MerchandiseType.fromJson(i as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<List<MerchandiseGroupType>> getMerchandiseGroupTypes() async {
    final response = await ApiClient.get<List<MerchandiseGroupType>>(
      '/merchandise/groups',
      fromJsonT: (json) {
        if (json is List) {
          return json.map((i) => MerchandiseGroupType.fromJson(i as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<List<MerchandiseCategory>> getMerchandiseCategories([int? groupTypeId]) async {
    final endpoint = groupTypeId != null
        ? '/merchandise/categories/group/$groupTypeId'
        : '/merchandise/categories';

    final response = await ApiClient.get<List<MerchandiseCategory>>(
      endpoint,
      fromJsonT: (json) {
        if (json is List) {
          return json.map((i) => MerchandiseCategory.fromJson(i as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<Merchandise> createMerchandise({
    required int sellerId,
    required int categoryId,
    int? merchandiseTypeId,
    required String title,
    required double price,
    String? description,
    String? options,
    String? filePath,
    Uint8List? imageBlob,
    Uint8List? imageBlob2,
    Uint8List? imageBlob3,
    Uint8List? imageBlob4,
    Uint8List? imageBlob5,
    int stockQuantity = 10,
  }) async {
    final Map<String, dynamic> body = {
      'sellerId': sellerId,
      'categoryId': categoryId,
      'title': title,
      'price': price,
      'stockQuantity': stockQuantity,
      'quantity': stockQuantity,
    };
    if (merchandiseTypeId != null) body['merchandiseTypeId'] = merchandiseTypeId;
    if (description != null) body['description'] = description;
    if (options != null) body['options'] = options;
    if (filePath != null) body['filePath'] = filePath;
    if (imageBlob != null) body['imageBlob'] = base64Encode(imageBlob);
    if (imageBlob2 != null) body['imageBlob2'] = base64Encode(imageBlob2);
    if (imageBlob3 != null) body['imageBlob3'] = base64Encode(imageBlob3);
    if (imageBlob4 != null) body['imageBlob4'] = base64Encode(imageBlob4);
    if (imageBlob5 != null) body['imageBlob5'] = base64Encode(imageBlob5);

    final response = await ApiClient.post<Merchandise>(
      '/merchandise',
      body: body,
      fromJsonT: (json) => Merchandise.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null) {
      throw ApiException(response.message ?? 'Failed to list merchandise');
    }
    return response.data!;
  }

  Future<Merchandise> updateMerchandise({
    required int id,
    String? title,
    double? price,
    String? description,
    int? stockQuantity,
    String? options,
    int? categoryId,
    int? merchandiseTypeId,
    Uint8List? imageBlob,
    Uint8List? imageBlob2,
    Uint8List? imageBlob3,
    Uint8List? imageBlob4,
    Uint8List? imageBlob5,
  }) async {
    final Map<String, dynamic> body = {};
    if (title != null) body['title'] = title;
    if (price != null) body['price'] = price;
    if (description != null) body['description'] = description;
    if (stockQuantity != null) {
      body['stockQuantity'] = stockQuantity;
      body['quantity'] = stockQuantity;
    }
    if (options != null) body['options'] = options;
    if (categoryId != null) body['categoryId'] = categoryId;
    if (merchandiseTypeId != null) body['merchandiseTypeId'] = merchandiseTypeId;
    if (imageBlob != null) body['imageBlob'] = base64Encode(imageBlob);
    if (imageBlob2 != null) body['imageBlob2'] = base64Encode(imageBlob2);
    if (imageBlob3 != null) body['imageBlob3'] = base64Encode(imageBlob3);
    if (imageBlob4 != null) body['imageBlob4'] = base64Encode(imageBlob4);
    if (imageBlob5 != null) body['imageBlob5'] = base64Encode(imageBlob5);

    final response = await ApiClient.put<Merchandise>(
      '/merchandise/$id',
      body: body,
      fromJsonT: (json) => Merchandise.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null) {
      throw ApiException(response.message ?? 'Failed to update merchandise');
    }
    return response.data!;
  }

  Future<List<MerchandiseReview>> getReviews(int merchandiseId) async {
    final response = await ApiClient.get<List<MerchandiseReview>>(
      '/merchandise/$merchandiseId/reviews',
      fromJsonT: (json) {
        if (json is List) {
          return json.map((i) => MerchandiseReview.fromJson(i as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }

  Future<MerchandiseReview> addReview({
    required int merchandiseId,
    required int userId,
    required int rating,
    String? comment,
  }) async {
    final response = await ApiClient.post<MerchandiseReview>(
      '/merchandise/$merchandiseId/reviews',
      body: {
        'merchandiseId': merchandiseId,
        'userId': userId,
        'rating': rating,
        'comment': comment,
      },
      fromJsonT: (json) => MerchandiseReview.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null) {
      throw ApiException(response.message ?? 'Failed to submit review');
    }
    return response.data!;
  }

  Future<PaymentHistory> processPayment({
    required int buyerId,
    int? merchandiseId,
    required String stripeChargeId,
    required double amount,
    String currency = 'USD',
  }) async {
    final response = await ApiClient.post<PaymentHistory>(
      '/payments',
      body: {
        'buyerId': buyerId,
        'merchandiseId': merchandiseId,
        'stripeChargeId': stripeChargeId,
        'amount': amount,
        'currency': currency,
      },
      fromJsonT: (json) => PaymentHistory.fromJson(json as Map<String, dynamic>),
    );
    if (response.data == null) {
      throw ApiException(response.message ?? 'Payment failed');
    }
    return response.data!;
  }

  Future<List<PaymentHistory>> getPaymentHistory(int buyerId) async {
    final response = await ApiClient.get<List<PaymentHistory>>(
      '/payments/buyer/$buyerId',
      fromJsonT: (json) {
        if (json is List) {
          return json.map((i) => PaymentHistory.fromJson(i as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );
    return response.data ?? [];
  }
}
