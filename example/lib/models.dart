class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final String imageEmoji;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.imageEmoji,
  });
}

class CartItem {
  final Product product;
  final int quantity;

  const CartItem({required this.product, required this.quantity});

  CartItem copyWith({int? quantity}) =>
      CartItem(product: product, quantity: quantity ?? this.quantity);

  double get subtotal => product.price * quantity;
}

class User {
  final String id;
  final String name;
  final String email;

  const User({required this.id, required this.name, required this.email});
}

const kProducts = [
  Product(
    id: 'p1',
    name: 'Flutter Hoodie',
    category: 'Apparel',
    price: 49.99,
    imageEmoji: '👕',
  ),
  Product(
    id: 'p2',
    name: 'Dart Mug',
    category: 'Accessories',
    price: 14.99,
    imageEmoji: '☕',
  ),
  Product(
    id: 'p3',
    name: 'Keyboard',
    category: 'Electronics',
    price: 129.00,
    imageEmoji: '⌨️',
  ),
  Product(
    id: 'p4',
    name: 'Mouse Pad',
    category: 'Electronics',
    price: 19.99,
    imageEmoji: '🖱️',
  ),
  Product(
    id: 'p5',
    name: 'Sticker Pack',
    category: 'Accessories',
    price: 8.99,
    imageEmoji: '🎨',
  ),
  Product(
    id: 'p6',
    name: 'Dev T-Shirt',
    category: 'Apparel',
    price: 29.99,
    imageEmoji: '👔',
  ),
];
