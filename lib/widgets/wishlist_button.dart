import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WishlistButton extends StatefulWidget {
  final String productId;

  const WishlistButton({super.key, required this.productId});

  @override
  State<WishlistButton> createState() => _WishlistButtonState();
}

class _WishlistButtonState extends State<WishlistButton> {
  bool _isWishlisted = false;
  final _user = FirebaseAuth.instance.currentUser;
  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _checkWishlist();
  }

  Future<void> _checkWishlist() async {
    if (_user == null) return;

    final doc = await _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('wishlist')
        .doc(widget.productId)
        .get();

    if (mounted) {
      setState(() {
        _isWishlisted = doc.exists;
      });
    }
  }

  Future<void> _toggleWishlist() async {
    if (_user == null) return;

    final ref = _firestore
        .collection('users')
        .doc(_user!.uid)
        .collection('wishlist')
        .doc(widget.productId);

    if (_isWishlisted) {
      await ref.delete();
      setState(() {
        _isWishlisted = false;
      });
    } else {
      await ref.set({'addedAt': Timestamp.now()});
      setState(() {
        _isWishlisted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _isWishlisted ? Icons.favorite : Icons.favorite_border,
        color: _isWishlisted ? Colors.redAccent : Colors.grey[600],
        size: 26,
      ),
      onPressed: _toggleWishlist,
    );
  }
}