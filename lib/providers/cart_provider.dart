import 'package:flutter/foundation.dart';
import '../models/cart.dart';
import '../services/cart_service.dart';

class CartProvider extends ChangeNotifier {
  final CartService _cartService = CartService();

  Cart? _cart;
  bool _isLoading = false;
  String? _errorMessage;

  Cart? get cart => _cart;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalItems => _cart?.totalItems ?? 0;
  double get subtotal => _cart?.subtotal ?? 0.0;
  List<CartItem> get items => _cart?.items ?? [];
  bool get isEmpty => _cart == null || _cart!.items.isEmpty;
  bool get isNotEmpty => !isEmpty;

  Future<void> loadCart(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _cart = await _cartService.getCart(userId);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addToCart({
    required int userId,
    int? merchandiseId,
    int? trackId,
    int quantity = 1,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedCart = await _cartService.addToCart(
        userId: userId,
        merchandiseId: merchandiseId,
        trackId: trackId,
        quantity: quantity,
      );
      if (updatedCart != null) {
        _cart = updatedCart;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateQuantity({
    required int userId,
    required int cartItemId,
    required int quantity,
  }) async {
    try {
      final updated = await _cartService.updateQuantity(
        userId: userId,
        cartItemId: cartItemId,
        quantity: quantity,
      );
      if (updated != null) {
        _cart = updated;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeItem({
    required int userId,
    required int cartItemId,
  }) async {
    try {
      final updated = await _cartService.removeItem(
        userId: userId,
        cartItemId: cartItemId,
      );
      if (updated != null) {
        _cart = updated;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> clearCart(int userId) async {
    try {
      await _cartService.clearCart(userId);
      if (_cart != null) {
        _cart = Cart(
          id: _cart!.id,
          userId: userId,
          items: [],
          totalItems: 0,
          subtotal: 0.0,
        );
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Clears this user's data on sign-out so the next person on the device doesn't see it.
  void reset() {
    _cart = null;
    _errorMessage = null;
    notifyListeners();
  }
}
