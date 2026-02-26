import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';

class CartProvider with ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.total);
  }

  void addItem(String productId, String productName, double price) {
    final existingIndex = _items.indexWhere((item) => item.id == productId);
    
    if (existingIndex >= 0) {
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + 1,
      );
    } else {
      _items.add(CartItem(
        id: productId,
        name: productName,
        price: price,
        quantity: 1,
      ));
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((item) => item.id == productId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    final index = _items.indexWhere((item) => item.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        _items.removeAt(index);
      } else {
        _items[index] = _items[index].copyWith(quantity: quantity);
      }
      notifyListeners();
    }
  }

  int getItemQuantity(String productId) {
    final item = _items.firstWhere((item) => item.id == productId, orElse: () => CartItem(id: '', name: '', price: 0));
    return item.quantity;
  }

  // Pour la persistance
  Map<String, dynamic> toJson() {
    return {
      'items': _items.map((item) => item.toJson()).toList(),
    };
  }

  void loadFromJson(Map<String, dynamic> json) {
    _items.clear();
    if (json['items'] is List) {
      for (var itemData in json['items']) {
        _items.add(CartItem.fromJson(itemData));
      }
    }
    notifyListeners();
  }
}
