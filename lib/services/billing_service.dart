import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:wealth_wise/models/user.dart';
import 'package:wealth_wise/services/database_service.dart';

/// A service class that handles all Google Play Billing operations
class BillingService {
  // Logger for debug information
  final Logger _logger = Logger('BillingService');

  // Database service for storing subscription status in Firebase
  final DatabaseService _databaseService = DatabaseService();

  // In-App Purchase instance
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  // Product IDs - make sure these match your Google Play Console configuration
  static const String _monthlySubscriptionId = 'wealthwise_monthly';
  static const String _annualSubscriptionId = 'wealthwise_annual';

  // All available products
  List<ProductDetails> _products = [];
  List<ProductDetails> get products => _products;

  // Subscription status
  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  // Loading status
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // Subscription end date
  DateTime? _subscriptionEndDate;
  DateTime? get subscriptionEndDate => _subscriptionEndDate;

  // Error message
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Purchase stream subscription
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  // Singleton pattern
  static final BillingService _instance = BillingService._internal();

  // Private constructor for singleton
  BillingService._internal();

  // Factory constructor
  factory BillingService() {
    return _instance;
  }

  // Keys for SharedPreferences
  static const String _isSubscribedKey = 'is_subscribed';
  static const String _subscriptionEndDateKey = 'subscription_end_date';
  static const String _productIdKey = 'subscription_product_id';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  /// Initialize the billing service
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;

    try {
      // Load subscription status from local storage first (for quick access)
      await _loadSubscriptionStatusFromPrefs();

      // Then try to get the latest status from the server
      final user = _auth.currentUser;
      if (user != null) {
        await _fetchSubscriptionFromDatabase(user.uid);
      }

      // Check if subscription is expired
      if (_subscriptionEndDate != null &&
          _subscriptionEndDate!.isBefore(DateTime.now())) {
        _isSubscribed = false;
        await _saveSubscriptionStatusToPrefs();

        if (user != null) {
          await _saveSubscriptionToDatabase(user.uid);
        }
      }

      // First check if the store is available at all
      final bool storeAvailable = await _inAppPurchase.isAvailable();
      if (!storeAvailable) {
        _logger.warning('Store is not available');
        _errorMessage = 'Store is not available';
        _isLoading = false;
        _createFallbackProducts();
        return;
      }

      _logger.info('Store is available, setting up purchase stream');

      // Listen for subscription purchases - this is critical for capturing purchase updates
      final purchaseStream = _inAppPurchase.purchaseStream;
      _purchaseSubscription?.cancel();
      _purchaseSubscription = purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () {
          _logger.info('Purchase stream done');
          _purchaseSubscription?.cancel();
        },
        onError: (error) {
          _logger.warning('Purchase stream error: $error');
        },
      );

      // Load available IAP products
      await _loadProducts();

      _isLoading = false;
    } catch (e) {
      _logger.warning('Error initializing billing service: $e');
      _errorMessage = 'Failed to initialize billing services';
      _isLoading = false;

      // Create fallback products for UI if none loaded
      if (_products.isEmpty) {
        _createFallbackProducts();
      }
    }
  }

  /// Load in-app purchase products from the store
  Future<void> _loadProducts() async {
    try {
      _logger.info('Loading IAP products');

      // Set up the product query with our product IDs
      final productIds = <String>{
        _monthlySubscriptionId,
        _annualSubscriptionId,
      };

      _logger.info('Querying product details for: $productIds');

      // Query the store for product details
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(productIds);

      if (response.error != null) {
        _logger.warning('Error querying products: ${response.error}');
        _createFallbackProducts();
        return;
      }

      if (response.notFoundIDs.isNotEmpty) {
        _logger.warning('Some products not found: ${response.notFoundIDs}');
      }

      // Store the product details
      if (response.productDetails.isNotEmpty) {
        _products = response.productDetails;
        _logger.info('Products loaded: ${_products.length}');
        _logger.info('Product IDs: ${_products.map((p) => p.id).join(', ')}');
      } else {
        _logger.warning('No products returned from store');
        _createFallbackProducts();
      }
    } catch (e) {
      _logger.warning('Error loading products: $e');
      _createFallbackProducts();
    }
  }

  /// Create fallback products for UI when real products fail to load
  void _createFallbackProducts() {
    _logger.info('Creating fallback products');
    _products = [
      ProductDetails(
        id: _monthlySubscriptionId,
        title: 'Monthly Premium',
        description: 'Unlimited access for one month',
        price: 'USD 3.99',
        rawPrice: 3.99,
        currencyCode: 'USD',
      ),
      ProductDetails(
        id: _annualSubscriptionId,
        title: 'Annual Premium',
        description: 'Unlimited access for one year (58% discount)',
        price: 'USD 19.99',
        rawPrice: 19.99,
        currencyCode: 'USD',
      ),
    ];
  }

  /// Handle purchase updates from the store
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    _logger.info('Received ${purchaseDetailsList.length} purchase updates');

    for (final purchaseDetails in purchaseDetailsList) {
      _logger.info(
          'Purchase update: ${purchaseDetails.productID} with status ${purchaseDetails.status}');

      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _logger.info('Purchase pending for ${purchaseDetails.productID}');
          break;

        case PurchaseStatus.error:
          _logger.warning('Purchase error: ${purchaseDetails.error?.message}');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _handleSuccessfulPurchase(purchaseDetails);
          break;

        case PurchaseStatus.canceled:
          _logger.info('Purchase canceled');
          break;
      }

      // It's critical to call completePurchase to finish the transaction
      if (purchaseDetails.pendingCompletePurchase) {
        _logger.info('Completing purchase for ${purchaseDetails.productID}');
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  /// Handle successful purchase or restored purchase
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    _logger.info('Handling successful purchase: ${purchase.productID}');

    try {
      // Verify the purchase is valid
      bool isValid = await _verifyPurchase(purchase);
      if (!isValid) {
        _logger.warning('Purchase verification failed: ${purchase.productID}');
        return;
      }

      // Determine subscription end date based on product ID
      DateTime endDate = DateTime.now();
      if (purchase.productID == _monthlySubscriptionId) {
        endDate = DateTime.now().add(const Duration(days: 30));
      } else if (purchase.productID == _annualSubscriptionId) {
        endDate = DateTime.now().add(const Duration(days: 365));
      }

      // Update subscription status
      _isSubscribed = true;
      _subscriptionEndDate = endDate;

      // Save the subscription details
      await _saveSubscriptionStatusToPrefs(purchase.productID);

      // Save to database if user is logged in
      final user = _auth.currentUser;
      if (user != null) {
        await _saveSubscriptionToDatabase(user.uid, purchase.productID);
      }

      _logger.info('Successfully processed purchase: ${purchase.productID}');
    } catch (e) {
      _logger.severe('Error handling successful purchase: $e');
    }
  }

  /// Verify that the purchase is valid
  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    // For production, consider implementing server-side validation
    // Here we're just checking that we have a valid purchase token

    // For Android
    if (Platform.isAndroid) {
      final GooglePlayPurchaseDetails googlePlayPurchase =
          purchase as GooglePlayPurchaseDetails;

      // Check if we have a purchase token
      if (googlePlayPurchase.billingClientPurchase.purchaseToken.isEmpty) {
        return false;
      }

      // In a real app, you would send this token to your server for verification
      // return await yourApiService.verifyPurchase(googlePlayPurchase.billingClientPurchase.purchaseToken);

      return true;
    }
    // For iOS
    else if (Platform.isIOS) {
      final AppStorePurchaseDetails appStorePurchase =
          purchase as AppStorePurchaseDetails;

      // Check if we have a valid purchase
      if (appStorePurchase.verificationData.serverVerificationData.isEmpty) {
        return false;
      }

      // In a real app, you would send this data to your server for verification
      // return await yourApiService.verifyPurchase(appStorePurchase.verificationData);

      return true;
    }

    return false;
  }

  /// Load subscription status from SharedPreferences
  Future<void> _loadSubscriptionStatusFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    _isSubscribed = prefs.getBool(_isSubscribedKey) ?? false;

    final endDateMillis = prefs.getInt(_subscriptionEndDateKey);
    if (endDateMillis != null) {
      _subscriptionEndDate = DateTime.fromMillisecondsSinceEpoch(endDateMillis);

      // Check if the subscription has expired
      if (_subscriptionEndDate!.isBefore(DateTime.now())) {
        _isSubscribed = false;
        _subscriptionEndDate = null;
        await _saveSubscriptionStatusToPrefs(null);
      }
    }

    _logger.info(
        'Loaded subscription status from prefs: $_isSubscribed, end date: $_subscriptionEndDate');
  }

  /// Save subscription status to SharedPreferences
  Future<void> _saveSubscriptionStatusToPrefs([String? productId]) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_isSubscribedKey, _isSubscribed);

    if (_subscriptionEndDate != null) {
      await prefs.setInt(_subscriptionEndDateKey,
          _subscriptionEndDate!.millisecondsSinceEpoch);

      if (productId != null) {
        await prefs.setString(_productIdKey, productId);
      }
    } else {
      await prefs.remove(_subscriptionEndDateKey);
      await prefs.remove(_productIdKey);
    }

    _logger.info(
        'Saved subscription status to prefs: $_isSubscribed, end date: $_subscriptionEndDate');
  }

  /// Fetch subscription status from the database
  Future<void> _fetchSubscriptionFromDatabase(String userId) async {
    try {
      final subscriptionData =
          await _databaseService.getUserFieldData(userId, 'subscriptions');

      if (subscriptionData != null &&
          subscriptionData is Map<String, dynamic>) {
        final endDateMillis = subscriptionData['endDateMillis'] as int?;
        final productId = subscriptionData['productId'] as String?;

        if (endDateMillis != null) {
          final endDate = DateTime.fromMillisecondsSinceEpoch(endDateMillis);

          // Only update if the database has a newer subscription
          if (endDate.isAfter(DateTime.now())) {
            _isSubscribed = true;
            _subscriptionEndDate = endDate;

            // Update local prefs with the latest data
            await _saveSubscriptionStatusToPrefs(productId);
          } else {
            // Subscription has expired
            _isSubscribed = false;
            _subscriptionEndDate = null;

            // Clear expired subscription data
            await _databaseService.updateUserField(userId, 'subscriptions', {
              'isSubscribed': false,
              'endDateMillis': null,
              'productId': null,
              'updatedAt': DateTime.now().millisecondsSinceEpoch,
            });

            await _saveSubscriptionStatusToPrefs(null);
          }
        }
      }

      _logger.info(
          'Fetched subscription from database for user $userId: $_isSubscribed, end date: $_subscriptionEndDate');
    } catch (e) {
      _logger.warning('Error fetching subscription from database: $e');
    }
  }

  /// Save subscription status to the database
  Future<void> _saveSubscriptionToDatabase(String userId,
      [String? productId]) async {
    try {
      if (!_isSubscribed || _subscriptionEndDate == null) {
        // Remove subscription data
        await _databaseService.removeField(userId, 'subscriptions');
        _logger.info('Removed subscription from database for user $userId');
        return;
      }

      // Save subscription data
      final subscriptionData = {
        'isSubscribed': _isSubscribed,
        'endDateMillis': _subscriptionEndDate!.millisecondsSinceEpoch,
        'productId': productId,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _databaseService.updateUserField(
          userId, 'subscriptions', subscriptionData);
      _logger.info(
          'Saved subscription to database for user $userId: $subscriptionData');
    } catch (e) {
      _logger.warning('Error saving subscription to database: $e');
    }
  }

  /// Purchase a subscription
  Future<bool> purchaseSubscription(ProductDetails product) async {
    try {
      _logger.info('Attempting to purchase ${product.id}');

      // We need to ensure we have a valid product to purchase
      ProductDetails validProduct;

      // First check if this exact product is in our loaded products
      try {
        validProduct = _products.firstWhere((p) => p.id == product.id);
        _logger.info('Using exact product match: ${validProduct.id}');
      } catch (e) {
        _logger.warning('Exact product not found in loaded products');

        // If we don't have the exact product, reload products and try again
        await _loadProducts();

        try {
          validProduct = _products.firstWhere((p) =>
              p.id == product.id ||
              p.id.contains(product.id) ||
              product.id.contains(p.id));
          _logger
              .info('Found similar product after reload: ${validProduct.id}');
        } catch (e) {
          _logger.severe('Product not available after reload: ${product.id}');
          return false;
        }
      }

      // Create purchase parameters
      final purchaseParam = PurchaseParam(productDetails: validProduct);

      _logger.info('Starting non-consumable purchase for ${validProduct.id}');

      // Start the purchase flow - subscriptions are non-consumable
      bool purchaseStarted =
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      _logger.info('Purchase flow started: $purchaseStarted');

      // Note: actual purchase completion is handled by the purchase stream listener
      return purchaseStarted;
    } catch (e) {
      _logger.severe('Error purchasing subscription: $e');
      return false;
    }
  }

  /// Restore purchases from platform store
  Future<bool> restorePurchases() async {
    try {
      // In a real app, this would call the platform's billing API
      // to restore purchases and validate receipts

      _logger.info('Restore purchases called - would check platform store');
      return await isUserSubscribed();
    } catch (e) {
      _logger.severe('Error restoring purchases: $e');
      return false;
    }
  }

  /// Cancel a user's subscription
  Future<bool> cancelSubscription() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return false;
      }

      // In a real app, this would call the platform's billing API to cancel
      // For this mock implementation, we'll just update the database

      await _updateUserSubscriptionFields(currentUser.uid, {
        'isSubscribed': false,
        'subscriptionType': null,
        'subscriptionEndDate': null,
      });

      _logger.info('Subscription cancelled successfully');
      return true;
    } catch (e) {
      _logger.severe('Error cancelling subscription: $e');
      return false;
    }
  }

  /// Update user subscription fields in the database
  Future<void> _updateUserSubscriptionFields(
      String userId, Map<String, dynamic> fields) async {
    try {
      await _firestore.collection('users').doc(userId).update(fields);
    } catch (e) {
      _logger.severe('Error updating user subscription fields: $e');
      rethrow;
    }
  }

  /// Check if the subscription is still valid
  bool isSubscriptionValid() {
    if (!_isSubscribed) return false;
    if (_subscriptionEndDate == null) return false;
    return _subscriptionEndDate!.isAfter(DateTime.now());
  }

  /// Clean up resources when done
  void dispose() {
    _purchaseSubscription?.cancel();
  }

  /// Get available subscription plans
  List<Map<String, dynamic>> getSubscriptionPlans() {
    return [
      {
        'id': _monthlySubscriptionId,
        'name': 'Monthly Premium',
        'price': 4.99,
        'period': 'month',
        'description': 'Unlimited access to all premium features',
        'isPopular': false,
      },
      {
        'id': _annualSubscriptionId,
        'name': 'Annual Premium',
        'price': 49.99,
        'period': 'year',
        'description': 'Save 16% compared to monthly plan',
        'isPopular': true,
      },
    ];
  }

  /// Check if a user is currently subscribed
  Future<bool> isUserSubscribed() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return false;
      }

      final user = await getUser(currentUser.uid);

      if (user == null || !user.isSubscribed) {
        return false;
      }

      // Check if subscription is still valid
      if (user.subscriptionEndDate != null) {
        final now = DateTime.now();
        return user.subscriptionEndDate!.isAfter(now);
      }

      return false;
    } catch (e) {
      _logger.severe('Error checking subscription status: $e');
      return false;
    }
  }

  /// Process a subscription purchase
  /// In a real app, this would integrate with platform billing APIs
  Future<bool> processPurchase(String planId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        _logger.warning('Cannot purchase: No user logged in');
        return false;
      }

      // Mock the purchase flow - in a real app, this would call the platform's billing API
      final success = await _processMockPurchase(planId);

      if (success) {
        // Calculate subscription end date based on plan
        final DateTime now = DateTime.now();
        late DateTime endDate;
        String subscriptionType;

        if (planId == _monthlySubscriptionId) {
          endDate = DateTime(now.year, now.month + 1, now.day);
          subscriptionType = 'monthly';
        } else {
          endDate = DateTime(now.year + 1, now.month, now.day);
          subscriptionType = 'yearly';
        }

        // Update user's subscription status in Firestore
        await _updateUserSubscriptionFields(currentUser.uid, {
          'isSubscribed': true,
          'subscriptionType': subscriptionType,
          'subscriptionEndDate': Timestamp.fromDate(endDate),
        });

        _logger.info('Subscription purchase successful: $planId');
        return true;
      } else {
        _logger.warning('Subscription purchase failed');
        return false;
      }
    } catch (e) {
      _logger.severe('Error during subscription purchase: $e');
      return false;
    }
  }

  /// Mock purchase process
  /// This would be replaced with actual platform billing API calls
  Future<bool> _processMockPurchase(String planId) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1, milliseconds: 500));

    // Mock successful purchase (would be actual payment processing in real app)
    return true;
  }

  Future<User?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return User.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      _logger.severe('Error getting user: $e');
      return null;
    }
  }
}
