import 'package:flutter/material.dart';
import 'models.dart';

// ---------------------------------------------------------------------------
// AuthProvider — manages the current logged-in user
// ---------------------------------------------------------------------------

class AuthProvider extends ChangeNotifier {
  User? _user;
  bool _loading = false;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;

  Future<void> login(String email, String password) async {
    _loading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    _user = User(id: 'u1', name: 'Alice Dev', email: email);
    _loading = false;
    notifyListeners();
  }

  void logout() {
    _user = null;
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// SettingsProvider — theme mode and preferred category filter
// ---------------------------------------------------------------------------

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _categoryFilter = 'All';

  ThemeMode get themeMode => _themeMode;
  String get categoryFilter => _categoryFilter;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void setCategoryFilter(String category) {
    if (_categoryFilter == category) return;
    _categoryFilter = category;
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// ProductRepository — product catalogue with async search
// ---------------------------------------------------------------------------

class ProductRepository extends ChangeNotifier {
  List<Product> _products = List.unmodifiable(kProducts);
  String _searchQuery = '';
  bool _loading = false;

  List<Product> get products => _products;
  String get searchQuery => _searchQuery;
  bool get loading => _loading;

  Future<void> search(String query) async {
    _searchQuery = query;
    _loading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    if (query.isEmpty) {
      _products = List.unmodifiable(kProducts);
    } else {
      _products = List.unmodifiable(
        kProducts.where(
          (p) =>
              p.name.toLowerCase().contains(query.toLowerCase()) ||
              p.category.toLowerCase().contains(query.toLowerCase()),
        ),
      );
    }

    _loading = false;
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _products = List.unmodifiable(kProducts);
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// FavoritesProvider — per-user wishlist (depends on AuthProvider)
// ---------------------------------------------------------------------------

class FavoritesProvider extends ChangeNotifier {
  AuthProvider _auth;
  // userId -> set of product ids
  final Map<String, Set<String>> _favorites = {};

  FavoritesProvider(this._auth) {
    _auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() => notifyListeners();

  // Called by ChangeNotifierProxyProvider when AuthProvider changes.
  void syncAuth(AuthProvider auth) {
    if (identical(_auth, auth)) return;
    _auth.removeListener(_onAuthChanged);
    _auth = auth;
    _auth.addListener(_onAuthChanged);
    notifyListeners();
  }

  Set<String> get _currentFavorites {
    final uid = _auth.user?.id;
    if (uid == null) return const {};
    return _favorites.putIfAbsent(uid, () => {});
  }

  bool isFavorite(String productId) => _currentFavorites.contains(productId);

  void toggle(String productId) {
    if (!_auth.isLoggedIn) return;
    final favs = _currentFavorites;
    if (favs.contains(productId)) {
      favs.remove(productId);
    } else {
      favs.add(productId);
    }
    notifyListeners();
  }

  int get count => _currentFavorites.length;

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// CartProvider — shopping cart (depends on AuthProvider via ProxyProvider)
// ---------------------------------------------------------------------------

class CartProvider extends ChangeNotifier {
  AuthProvider? _auth;
  final Map<String, CartItem> _items = {};

  // Called by ProxyProvider when AuthProvider updates.
  void update(AuthProvider auth) {
    if (_auth?.user?.id != auth.user?.id) {
      _items.clear();
      notifyListeners();
    }
    _auth = auth;
  }

  List<CartItem> get items => List.unmodifiable(_items.values);

  int get itemCount =>
      _items.values.fold(0, (sum, item) => sum + item.quantity);

  double get total =>
      _items.values.fold(0.0, (sum, item) => sum + item.subtotal);

  bool contains(String productId) => _items.containsKey(productId);

  void addProduct(Product product) {
    if (_items.containsKey(product.id)) {
      _items[product.id] = _items[product.id]!.copyWith(
        quantity: _items[product.id]!.quantity + 1,
      );
    } else {
      _items[product.id] = CartItem(product: product, quantity: 1);
    }
    notifyListeners();
  }

  void removeProduct(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  void increment(String productId) {
    if (!_items.containsKey(productId)) return;
    _items[productId] = _items[productId]!.copyWith(
      quantity: _items[productId]!.quantity + 1,
    );
    notifyListeners();
  }

  void decrement(String productId) {
    final item = _items[productId];
    if (item == null) return;
    if (item.quantity <= 1) {
      _items.remove(productId);
    } else {
      _items[productId] = item.copyWith(quantity: item.quantity - 1);
    }
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
