import '../models/cart.dart';
import 'api_client.dart';

class CartService {
  Future<Cart?> getCart(int userId) async {
    final response = await ApiClient.get<Cart>(
      '/cart/user/$userId',
      fromJsonT: (json) => Cart.fromJson(json as Map<String, dynamic>),
    );
    return response.data;
  }

  Future<Cart?> addToCart({
    required int userId,
    int? merchandiseId,
    int? trackId,
    int quantity = 1,
  }) async {
    final response = await ApiClient.post<Cart>(
      '/cart/items',
      body: {
        'userId': userId,
        'merchandiseId': merchandiseId,
        'trackId': trackId,
        'quantity': quantity,
      },
      fromJsonT: (json) => Cart.fromJson(json as Map<String, dynamic>),
    );
    return response.data;
  }

  Future<Cart?> updateQuantity({
    required int userId,
    required int cartItemId,
    required int quantity,
  }) async {
    final response = await ApiClient.put<Cart>(
      '/cart/user/$userId/items/$cartItemId',
      body: {
        'quantity': quantity,
      },
      fromJsonT: (json) => Cart.fromJson(json as Map<String, dynamic>),
    );
    return response.data;
  }

  Future<Cart?> removeItem({
    required int userId,
    required int cartItemId,
  }) async {
    final response = await ApiClient.delete<Cart>(
      '/cart/user/$userId/items/$cartItemId',
      fromJsonT: (json) => Cart.fromJson(json as Map<String, dynamic>),
    );
    return response.data;
  }

  Future<void> clearCart(int userId) async {
    await ApiClient.delete<void>('/cart/user/$userId');
  }
}
