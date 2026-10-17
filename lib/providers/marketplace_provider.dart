import 'package:flutter/foundation.dart';
import '../models/merchandise.dart';
import '../models/merchandise_review.dart';
import '../models/payment_history.dart';
import '../services/marketplace_service.dart';

class MarketplaceProvider extends ChangeNotifier {
  final MarketplaceService _marketplaceService = MarketplaceService();

  List<Merchandise> _merchandiseList = [];
  List<MerchandiseType> _types = [];
  List<MerchandiseGroupType> _groupTypes = [];
  List<MerchandiseCategory> _categories = [];
  List<PaymentHistory> _paymentHistory = [];
  final Map<int, List<MerchandiseReview>> _reviewsByMerchandiseId = {};
  String _selectedCategory = 'All';
  bool _isLoading = false;
  String? _errorMessage;

  List<Merchandise> get merchandiseList {
    if (_selectedCategory == 'All') return _merchandiseList;
    return _merchandiseList.where((m) {
      final grpName = (m.groupTypeName ?? '').toLowerCase();
      final catName = (m.categoryName ?? m.merchandiseTypeName ?? '').toLowerCase();
      final target = _selectedCategory.toLowerCase();

      return grpName.contains(target) ||
          catName.contains(target) ||
          (target == 'sound kits' && (grpName.contains('music') || catName.contains('beat') || catName.contains('sample') || catName.contains('track'))) ||
          (target == 'merchandise' && (grpName.contains('apparel') || grpName.contains('collectible') || grpName.contains('accessories') || grpName.contains('media')));
    }).toList();
  }

  List<MerchandiseType> get types => _types;
  List<MerchandiseGroupType> get groupTypes => _groupTypes;
  List<MerchandiseCategory> get categories => _categories;
  List<PaymentHistory> get paymentHistory => _paymentHistory;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<MerchandiseReview> getReviewsFor(int merchandiseId) =>
      _reviewsByMerchandiseId[merchandiseId] ?? [];

  Merchandise? getMerchandise(int id) {
    try {
      return _merchandiseList.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadMarketplace([int? buyerId]) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _marketplaceService.getAllMerchandise(),
        _marketplaceService.getMerchandiseTypes(),
        _marketplaceService.getMerchandiseGroupTypes(),
        _marketplaceService.getMerchandiseCategories(),
        if (buyerId != null) _marketplaceService.getPaymentHistory(buyerId),
      ]);

      _merchandiseList = results[0] as List<Merchandise>;
      _types = results[1] as List<MerchandiseType>;
      _groupTypes = results[2] as List<MerchandiseGroupType>;
      _categories = results[3] as List<MerchandiseCategory>;
      if (buyerId != null && results.length > 4) {
        _paymentHistory = results[4] as List<PaymentHistory>;
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Merchandise>> getMerchandiseBySeller(int sellerId) async {
    try {
      return await _marketplaceService.getMerchandiseBySeller(sellerId);
    } catch (e) {
      return _merchandiseList.where((m) => m.sellerId == sellerId).toList();
    }
  }

  Future<void> loadCategories() async {
    try {
      final results = await Future.wait([
        _marketplaceService.getMerchandiseGroupTypes(),
        _marketplaceService.getMerchandiseCategories(),
      ]);
      _groupTypes = results[0] as List<MerchandiseGroupType>;
      _categories = results[1] as List<MerchandiseCategory>;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void filterByCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<List<MerchandiseReview>> loadReviews(int merchandiseId) async {
    try {
      final reviews = await _marketplaceService.getReviews(merchandiseId);
      _reviewsByMerchandiseId[merchandiseId] = reviews;
      notifyListeners();
      return reviews;
    } catch (e) {
      debugPrint('Failed to load reviews for merch $merchandiseId: $e');
      return [];
    }
  }

  Future<MerchandiseReview?> submitReview({
    required int merchandiseId,
    required int userId,
    required int rating,
    String? comment,
  }) async {
    try {
      final rev = await _marketplaceService.addReview(
        merchandiseId: merchandiseId,
        userId: userId,
        rating: rating,
        comment: comment,
      );
      final currentList = _reviewsByMerchandiseId[merchandiseId] ?? [];
      _reviewsByMerchandiseId[merchandiseId] = [rev, ...currentList];

      final reviews = _reviewsByMerchandiseId[merchandiseId]!;
      final double avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
      final idx = _merchandiseList.indexWhere((m) => m.id == merchandiseId);
      if (idx != -1) {
        _merchandiseList[idx] = _merchandiseList[idx].copyWith(
          averageRating: double.parse(avg.toStringAsFixed(1)),
          reviewCount: reviews.length,
        );
      }
      notifyListeners();
      return rev;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<PaymentHistory?> purchaseItem({
    required int buyerId,
    required Merchandise item,
    String? stripeChargeId,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final chargeId = stripeChargeId ?? 'ch_${DateTime.now().millisecondsSinceEpoch}_sm';
      final payment = await _marketplaceService.processPayment(
        buyerId: buyerId,
        merchandiseId: item.id,
        stripeChargeId: chargeId,
        amount: item.price,
        currency: 'USD',
      );
      _paymentHistory.insert(0, payment);

      // Decrement stock locally
      final idx = _merchandiseList.indexWhere((m) => m.id == item.id);
      if (idx != -1) {
        final current = _merchandiseList[idx];
        _merchandiseList[idx] = current.copyWith(
          stockQuantity: (current.stockQuantity - 1).clamp(0, 999999),
        );
      }

      notifyListeners();
      return payment;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Merchandise?> createMerchandise({
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final item = await _marketplaceService.createMerchandise(
        sellerId: sellerId,
        categoryId: categoryId,
        merchandiseTypeId: merchandiseTypeId,
        title: title,
        price: price,
        description: description,
        options: options,
        filePath: filePath,
        imageBlob: imageBlob,
        imageBlob2: imageBlob2,
        imageBlob3: imageBlob3,
        imageBlob4: imageBlob4,
        imageBlob5: imageBlob5,
        stockQuantity: stockQuantity,
      );
      _merchandiseList.insert(0, item);
      notifyListeners();
      return item;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Merchandise?> updateMerchandise({
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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _marketplaceService.updateMerchandise(
        id: id,
        title: title,
        price: price,
        description: description,
        stockQuantity: stockQuantity,
        options: options,
        categoryId: categoryId,
        merchandiseTypeId: merchandiseTypeId,
        imageBlob: imageBlob,
        imageBlob2: imageBlob2,
        imageBlob3: imageBlob3,
        imageBlob4: imageBlob4,
        imageBlob5: imageBlob5,
      );
      final idx = _merchandiseList.indexWhere((m) => m.id == id);
      if (idx != -1) {
        _merchandiseList[idx] = updated;
      } else {
        _merchandiseList.insert(0, updated);
      }
      notifyListeners();
      return updated;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
