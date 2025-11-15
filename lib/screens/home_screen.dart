import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/admin_panel_screen.dart';
import '../widgets/product_card.dart';
import '../screens/product_detail_screen.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_screen.dart';
import 'package:provider/provider.dart';
import 'package:ecommerce_app/screens/order_history_screen.dart';
import 'package:ecommerce_app/screens/profile_screen.dart';
import 'package:ecommerce_app/widgets/notification_icon.dart';
import 'package:ecommerce_app/screens/chat_screen.dart';
import 'package:ecommerce_app/screens/wishlist_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _userRole = 'user';
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedCategory = 'All';
  final double _minPrice = 0.0;
  final double _maxPrice = 50000.0;
  late RangeValues _priceRange;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    _priceRange = RangeValues(_minPrice, _maxPrice);
  }

  Future<void> _fetchUserRole() async {
    if (_currentUser == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        setState(() {
          _userRole = doc.data()!['role'];
        });
      }
    } catch (e) {
      print("Error fetching user role: $e");
    }
  }

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  Widget _buildCategoryChip(String category) {
    final theme = Theme.of(context);
    final isSelected = _selectedCategory == category;
    return ChoiceChip(
      label: Text(category),
      selected: isSelected,
      backgroundColor: Colors.grey[200],
      selectedColor: theme.colorScheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? theme.colorScheme.primary : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? theme.colorScheme.primary : Colors.grey.shade400,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedCategory = category;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Image.asset(
          'assets/images/app_logo.png',
          height: 50,
        ),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cart, child) {
              return Badge(
                label: Text(cart.itemCount.toString()),
                isLabelVisible: cart.itemCount > 0,
                child: IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CartScreen(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const NotificationIcon(),
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const WishlistScreen(),
                ),
              );
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const OrderHistoryScreen(),
                ),
              );
            },
          ),
          if (_userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AdminPanelScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),

      body: SafeArea(
        child: Column(
          children: [
            // Category Filter
            Container(
              height: 50,
              margin: const EdgeInsets.symmetric(vertical: 10),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  _buildCategoryChip('All'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Table Lamps'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Floor Lamps'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Hanging Lights'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Wall Lamps'),
                ],
              ),
            ),

            // Price Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price: ₱${_priceRange.start.round()} - ₱${_priceRange.end.round()}',
                    style: theme.textTheme.bodyMedium!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  RangeSlider(
                    values: _priceRange,
                    min: _minPrice,
                    max: _maxPrice,
                    divisions: 100,
                    labels: RangeLabels(
                      '₱${_priceRange.start.round()}',
                      '₱${_priceRange.end.round()}',
                    ),
                    activeColor: theme.colorScheme.primary,
                    onChanged: (RangeValues newValues) {
                      setState(() {
                        _priceRange = RangeValues(
                          newValues.start.roundToDouble(),
                          newValues.end.roundToDouble(),
                        );
                      });
                    },
                  ),
                ],
              ),
            ),

            // Products Grid
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('products')
                    .where(
                  'category',
                  isEqualTo:
                  _selectedCategory == 'All' ? null : _selectedCategory,
                )
                    .where('price', isGreaterThanOrEqualTo: _priceRange.start)
                    .where('price', isLessThanOrEqualTo: _priceRange.end)
                    .orderBy('price', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No products found.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    );
                  }

                  final products = snapshot.data!.docs;

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final productDoc = products[index];
                      final productData = productDoc.data() as Map<String, dynamic>;

                      return ProductCard(
                        productId: productDoc.id,
                        productName: productData['name'],
                        price: productData['price'],
                        imageUrl: productData['imageUrl'],
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ProductDetailScreen(
                                productData: productData,
                                productId: productDoc.id,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),

      // Floating Chat Button
      floatingActionButton: _userRole == 'user'
          ? StreamBuilder<DocumentSnapshot>(
        stream: _firestore
            .collection('chats')
            .doc(_currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          int unreadCount = 0;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            unreadCount = data?['unreadByUserCount'] ?? 0;
          }

          return Badge(
            label: Text('$unreadCount'),
            isLabelVisible: unreadCount > 0,
            child: FloatingActionButton.extended(
              icon: const Icon(Icons.support_agent_outlined),
              label: const Text('Contact Admin'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      chatRoomId: _currentUser!.uid,
                    ),
                  ),
                );
              },
            ),
          );
        },
      )
          : null,
    );
  }
}
