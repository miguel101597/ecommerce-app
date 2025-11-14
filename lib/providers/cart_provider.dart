import 'dart:async'; // 1. ADD THIS (for StreamSubscription)
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 2. ADD THIS
import 'package:cloud_firestore/cloud_firestore.dart'; // 3. ADD THIS


// 1. A simple class to hold the data for an item in the cart
class CartItem {
  final String id;       // The unique product ID
  final String name;
  final double price;
  int quantity;        // Quantity can change, so it's not final

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1, // Default to 1 when added
  });

  // 1. ADD THIS: A method to convert our CartItem object into a Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }

  // 2. ADD THIS: A factory constructor to create a CartItem from a Map
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      name: json['name'],
      price: json['price'],
      quantity: json['quantity'],
    );
  }
}



// (Put the CartItem class from Part 1 here)

// 1. The CartProvider class "mixes in" ChangeNotifier
class CartProvider with ChangeNotifier {

  // 4. Change this: _items is no longer final
  List<CartItem> _items = [];

  // 5. ADD THESE: New properties for auth and database
  String? _userId; // Will hold the current user's ID
  StreamSubscription? _authSubscription; // To listen to auth changes

  // 6. ADD THESE: Get Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 3. A public "getter" to let widgets *read* the list of items
  List<CartItem> get items => _items;

  // 4. A public "getter" to calculate the total number of items
  int get itemCount {
    int total = 0;
    for (var item in _items) {
      total += item.quantity;
    }
    return total;
  }

  // 5. A public "getter" to calculate the total price
  double get totalPrice {
    double total = 0.0;
    for (var item in _items) {
      total += (item.price * item.quantity);
    }
    return total;
  }

  // 7. ADD THIS CONSTRUCTOR
  CartProvider() {
    print('CartProvider initialized');
    // Listen to authentication changes
    _authSubscription = _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        // User is logged out
        print('User logged out, clearing cart.');
        _userId = null;
        _items = []; // Clear local cart
      } else {
        // User is logged in
        print('User logged in: ${user.uid}. Fetching cart...');
        _userId = user.uid;
        _fetchCart(); // Load their cart from Firestore
      }
      // Notify listeners to update UI (e.g., clear cart badge on logout)
      notifyListeners();
    });
  }

  // 8. ADD THIS: Fetches the cart from Firestore
  Future<void> _fetchCart() async {
    if (_userId == null) return; // Not logged in, nothing to fetch

    try {
      // 1. Get the user's specific cart document
      final doc = await _firestore.collection('userCarts').doc(_userId).get();

      if (doc.exists && doc.data()!['cartItems'] != null) {
        // 2. Get the list of items from the document
        final List<dynamic> cartData = doc.data()!['cartItems'];

        // 3. Convert that list of Maps into our List<CartItem>
        //    (This is why we made CartItem.fromJson!)
        _items = cartData.map((item) => CartItem.fromJson(item)).toList();
        print('Cart fetched successfully: ${_items.length} items');
      } else {
        // 4. The user has no saved cart, start with an empty one
        _items = [];
      }
    } catch (e) {
      print('Error fetching cart: $e');
      _items = []; // On error, default to an empty cart
    }
    notifyListeners(); // Update the UI
  }

  // 9. ADD THIS: Saves the current local cart to Firestore
  Future<void> _saveCart() async {
    if (_userId == null) return; // Not logged in, nowhere to save

    try {
      // 1. Convert our List<CartItem> into a List<Map>
      //    (This is why we made toJson()!)
      final List<Map<String, dynamic>> cartData =
          _items.map((item) => item.toJson()).toList();

      // 2. Find the user's document and set the 'cartItems' field
      await _firestore.collection('userCarts').doc(_userId).set({
        'cartItems': cartData,
      });
      print('Cart saved to Firestore');
    } catch (e) {
      print('Error saving cart: $e');
    }
  }

  // 6. The main logic: "Add Item to Cart"
  void addItem(String id, String name, double price) {
    // 7. Check if the item is already in the cart
    var index = _items.indexWhere((item) => item.id == id);

    if (index != -1) {
      // 8. If YES: just increase the quantity
      _items[index].quantity++;
    } else {
      // 9. If NO: add it to the list as a new item
      _items.add(CartItem(id: id, name: name, price: price));
    }

    _saveCart(); // 10. ADD THIS LINE
    notifyListeners();
  }

  // 11. The "Remove Item from Cart" logic
  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);

    _saveCart(); // 11. ADD THIS LINE
    notifyListeners(); // Tell widgets to rebuild
  }

  // 12. ADD THIS METHOD (or update it if it exists)
  @override
  void dispose() {
    _authSubscription?.cancel(); // Cancel the auth listener
    super.dispose();
  }
}