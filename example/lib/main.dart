// ============================================================
// flutter_state_migrator — Example (BEFORE migration)
//
// A realistic e-commerce app written with the Provider package.
// Run the migrator on this directory to see the automated
// Provider → Riverpod conversion in action:
//
//   dart run bin/migrator.dart --mode=aggressive --dry-run example/
//
// The app demonstrates patterns the migrator handles end-to-end:
//   - ChangeNotifier (AuthProvider, CartProvider, etc.)
//   - MultiProvider root with ChangeNotifierProxyProvider
//   - Consumer / Consumer2 for reactive UI
//   - Selector for precision rebuilds
//   - context.read / context.select / context.watch
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models.dart';
import 'providers.dart';

// ---------------------------------------------------------------------------
// Entry point — MultiProvider wires all providers at the root
// ---------------------------------------------------------------------------

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ProductRepository()),
        // FavoritesProvider depends on AuthProvider.
        ChangeNotifierProxyProvider<AuthProvider, FavoritesProvider>(
          create: (ctx) => FavoritesProvider(ctx.read<AuthProvider>()),
          update: (ctx, auth, prev) {
            prev!.syncAuth(auth);
            return prev;
          },
        ),
        // CartProvider depends on AuthProvider — clears on user change.
        ChangeNotifierProxyProvider<AuthProvider, CartProvider>(
          create: (_) => CartProvider(),
          update: (_, auth, cart) => cart!..update(auth),
        ),
      ],
      child: const ShopApp(),
    ),
  );
}

// ---------------------------------------------------------------------------
// ShopApp — reads theme from SettingsProvider via Selector
// ---------------------------------------------------------------------------

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Selector ensures only theme changes trigger a rebuild here.
    final themeMode = context.select<SettingsProvider, ThemeMode>(
      (s) => s.themeMode,
    );
    return MaterialApp(
      title: 'Provider Shop Demo',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const CatalogScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// CatalogScreen — product listing with search and category filter
// ---------------------------------------------------------------------------

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Shop'),
        actions: [
          // Badge showing cart item count — uses Selector for precision.
          Selector<CartProvider, int>(
            selector: (_, cart) => cart.itemCount,
            builder: (ctx, count, _) => Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => const CartScreen()),
                  ),
                ),
                if (count > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: CircleAvatar(
                      radius: 8,
                      backgroundColor: Colors.red,
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Auth toggle.
          Consumer<AuthProvider>(
            builder: (_, auth, __) => IconButton(
              icon: Icon(auth.isLoggedIn ? Icons.logout : Icons.login),
              tooltip: auth.isLoggedIn ? 'Logout' : 'Login',
              onPressed: () {
                if (auth.isLoggedIn) {
                  auth.logout();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
            ),
          ),
          // Theme toggle.
          Consumer<SettingsProvider>(
            builder: (_, settings, __) => IconButton(
              icon: Icon(
                settings.themeMode == ThemeMode.dark
                    ? Icons.light_mode
                    : Icons.dark_mode,
              ),
              onPressed: () => settings.setThemeMode(
                settings.themeMode == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar.
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    context.read<ProductRepository>().clearSearch();
                  },
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (q) => context.read<ProductRepository>().search(q),
            ),
          ),
          // Category chips — Selector watches only the filter string.
          Selector<SettingsProvider, String>(
            selector: (_, s) => s.categoryFilter,
            builder: (ctx, active, _) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: ['All', 'Apparel', 'Accessories', 'Electronics']
                    .map(
                      (cat) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat),
                          selected: active == cat,
                          onSelected: (_) => ctx
                              .read<SettingsProvider>()
                              .setCategoryFilter(cat),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Product grid — Consumer2 watches both repo and settings.
          Expanded(
            child: Consumer2<ProductRepository, SettingsProvider>(
              builder: (ctx, repo, settings, _) {
                if (repo.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final filtered = settings.categoryFilter == 'All'
                    ? repo.products
                    : repo.products
                          .where((p) => p.category == settings.categoryFilter)
                          .toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No products found.'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => ProductCard(product: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ProductCard — per-item card with add-to-cart and favourite actions
// ---------------------------------------------------------------------------

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Center(
                child: Text(
                  product.imageEmoji,
                  style: const TextStyle(fontSize: 56),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              product.name,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
          Row(
            children: [
              // Favourite toggle — Selector watches only this product's state.
              Selector<FavoritesProvider, bool>(
                selector: (_, favs) => favs.isFavorite(product.id),
                builder: (ctx, isFav, _) => IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.red : null,
                    size: 20,
                  ),
                  onPressed: () {
                    final auth = ctx.read<AuthProvider>();
                    if (!auth.isLoggedIn) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Login to save favourites'),
                        ),
                      );
                      return;
                    }
                    ctx.read<FavoritesProvider>().toggle(product.id);
                  },
                ),
              ),
              const Spacer(),
              // Add-to-cart — Selector watches only in-cart state.
              Selector<CartProvider, bool>(
                selector: (_, cart) => cart.contains(product.id),
                builder: (ctx, inCart, _) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilledButton.tonal(
                    onPressed: () =>
                        ctx.read<CartProvider>().addProduct(product),
                    child: Text(inCart ? 'Add more' : 'Add'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CartScreen — checkout view with quantity controls
// ---------------------------------------------------------------------------

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: Consumer<CartProvider>(
        builder: (ctx, cart, _) {
          if (cart.items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64),
                  SizedBox(height: 16),
                  Text('Your cart is empty'),
                ],
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final item = cart.items[i];
                    return ListTile(
                      leading: Text(
                        item.product.imageEmoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                      title: Text(item.product.name),
                      subtitle: Text(
                        '\$${item.product.price.toStringAsFixed(2)} each',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () => cart.decrement(item.product.id),
                          ),
                          Text('${item.quantity}'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => cart.increment(item.product.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                cart.removeProduct(item.product.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total',
                            style: Theme.of(ctx).textTheme.labelMedium,
                          ),
                          Text(
                            '\$${cart.total.toStringAsFixed(2)}',
                            style: Theme.of(ctx).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        icon: const Icon(Icons.payment),
                        label: const Text('Checkout'),
                        onPressed: () {
                          cart.clear();
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Order placed!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// LoginScreen — simulated async login
// ---------------------------------------------------------------------------

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(text: 'alice@example.com');
  final _passwordController = TextEditingController(text: 'secret');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          if (auth.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    await auth.login(
                      _emailController.text,
                      _passwordController.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Sign In'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
