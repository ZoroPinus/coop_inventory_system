import 'package:flutter/foundation.dart';

class CartNotifier extends ChangeNotifier {
  static final CartNotifier _instance = CartNotifier._internal();
  factory CartNotifier() => _instance;
  CartNotifier._internal();

  int _itemCount = 0;
  double _total = 0.0;

  int get itemCount => _itemCount;
  double get total => _total;

  void updateCart(int count, double total) {
    _itemCount = count;
    _total = total;
    notifyListeners();
  }

  void clearCart() {
    _itemCount = 0;
    _total = 0.0;
    notifyListeners();
  }
}
