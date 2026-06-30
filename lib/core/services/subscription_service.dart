import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Product IDs ───────────────────────────────────────────────────────────────

const kProductMonthly = 'digdeeper_pro_monthly';
const kProductYearly  = 'digdeeper_pro_yearly';
const _kProductIds    = {kProductMonthly, kProductYearly};

const _kPrefIsPro     = 'subscription_is_pro';

// ── SubscriptionService ───────────────────────────────────────────────────────

/// Wraps Flutter's in_app_purchase (StoreKit on iOS).
/// Exposes [isPro], [products], [purchase], [restorePurchases].
class SubscriptionService extends ChangeNotifier {
  SubscriptionService._();

  static final SubscriptionService instance = SubscriptionService._();

  // ── State ─────────────────────────────────────────────────────────────────

  bool _isPro = false;
  bool get isPro => _isPro;

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  bool _loading = true;
  bool get loading => _loading;

  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  String? _pendingError;
  String? get pendingError => _pendingError;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    // Restore cached status so premium features work offline / before network
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(_kPrefIsPro) ?? false;

    _isAvailable = await InAppPurchase.instance.isAvailable();
    if (!_isAvailable) {
      _loading = false;
      notifyListeners();
      return;
    }

    // Listen to purchase updates (purchases, restores, errors)
    _purchaseSub = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) => debugPrint('IAP stream error: $e'),
    );

    await _loadProducts();
    await _restoreSilently();

    _loading = false;
    notifyListeners();
  }

  Future<void> _loadProducts() async {
    final response = await InAppPurchase.instance
        .queryProductDetails(_kProductIds);
    if (response.error != null) {
      debugPrint('IAP product query error: ${response.error}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('IAP products not found in App Store: ${response.notFoundIDs}');
    }
    debugPrint('IAP products loaded: ${response.productDetails.map((p) => p.id).toList()}');
    _products = response.productDetails
      ..sort((a, b) {
        // Monthly first, yearly second in UI
        if (a.id == kProductMonthly) return -1;
        if (b.id == kProductMonthly) return 1;
        return 0;
      });
  }

  /// Called on startup — silently restores any existing subscription without
  /// showing a system dialog (iOS only triggers a dialog on explicit restore).
  Future<void> _restoreSilently() async {
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      debugPrint('Silent restore error: $e');
    }
  }

  // ── Purchase ──────────────────────────────────────────────────────────────

  /// Call when user taps a buy button. Pass a [ProductDetails] from [products].
  Future<void> purchase(ProductDetails product) async {
    _pendingError = null;
    final param = PurchaseParam(productDetails: product);
    try {
      await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
    } catch (e) {
      _pendingError = e.toString();
      notifyListeners();
    }
  }

  /// Explicit restore (user tapped "Restore Purchases" button).
  Future<void> restorePurchases() async {
    _pendingError = null;
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      _pendingError = 'Restore failed. Please try again.';
      notifyListeners();
    }
  }

  // ── Purchase stream handler ───────────────────────────────────────────────

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliverPro(purchase);
          break;
        case PurchaseStatus.error:
          _pendingError = purchase.error?.message ?? 'Purchase failed.';
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          // Nothing to do
          break;
        case PurchaseStatus.pending:
          // StoreKit is processing — nothing to do yet
          break;
      }

      // Must call completePurchase for every terminal state
      if (purchase.status != PurchaseStatus.pending) {
        await InAppPurchase.instance.completePurchase(purchase);
      }
    }
  }

  Future<void> _deliverPro(PurchaseDetails purchase) async {
    _isPro = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefIsPro, true);
    // Write to Firestore so Cloud Functions can verify pro status server-side
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'isPro': true, 'isPremium': true}, SetOptions(merge: true));
    }
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  ProductDetails? productById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    super.dispose();
  }
}
