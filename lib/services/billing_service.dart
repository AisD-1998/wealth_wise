import 'dart:async';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wealth_wise/services/database_service.dart';
import 'package:logging/logging.dart';

/// A service class that handles all Google Play Billing operations
class BillingService {
  // Logger for debug information
  final Logger _logger = Logger('BillingService');

  // Database service for storing subscription status in Firebase
  final DatabaseService _databaseService = DatabaseService();

  // In-App Purchase instance
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  // Product IDs - make sure these match your Google Play Console configuration
  static const String _monthlySubscriptionId = 'wealthwise_monthly_premium';
  static const String _annualSubscriptionId = 'wealthwise_annual_premium';

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

  /// Initialize the billing service
  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;

    try {
      // Load subscription status from local storage first (for quick access)
      await _loadSubscriptionStatusFromPrefs();

      // Then try to get the latest status from the server
      final user = FirebaseAuth.instance.currentUser;
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

      // Configure the Google Play billing client (Android only)
      if (Platform.isAndroid) {
        // No need to manually call enablePendingPurchases - it's automatically
        // handled by the plugin when you create a purchase
      }

      // Listen for subscription purchases
      final purchaseStream = _inAppPurchase.purchaseStream;
      _purchaseSubscription = purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: _purchaseSubscription?.cancel,
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
      final available = await _inAppPurchase.isAvailable();
      if (!available) {
        _logger.warning('In-app purchase is not available');
        _createFallbackProducts();
        return;
      }

      // Set up the product query with our product IDs
      final productIds = <String>{
        _monthlySubscriptionId,
        _annualSubscriptionId,
      };

      // Query the store for product details
      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(productIds);

      if (response.error != null) {
        _logger.warning('Error querying products: ${response.error}');
        _createFallbackProducts();
        return;
      }

      // Store the product details
      if (response.productDetails.isNotEmpty) {
        _products = response.productDetails;
        _logger.info('Products loaded: ${_products.length}');
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
        price: 'USD 4.99',
        rawPrice: 4.99,
        currencyCode: 'USD',
      ),
      ProductDetails(
        id: _annualSubscriptionId,
        title: 'Annual Premium',
        description: 'Unlimited access for one year (58% discount)',
        price: 'USD 29.99',
        rawPrice: 29.99,
        currencyCode: 'USD',
      ),
    ];
  }

  /// Buy a subscription
  Future<void> buySubscription(ProductDetails product,
      {bool testMode = true}) async {
    try {
      _logger.info('Attempting to purchase ${product.id}');

      // Show a loading state
      _isLoading = true;

      if (testMode) {
        // Simulate successful purchase for testing
        _logger.info('TEST MODE: Simulating successful purchase');
        await Future.delayed(const Duration(seconds: 2));

        // Determine subscription end date based on product ID
        DateTime endDate = DateTime.now();
        if (product.id.contains('monthly')) {
          endDate = DateTime.now().add(const Duration(days: 30));
        } else if (product.id.contains('annual')) {
          endDate = DateTime.now().add(const Duration(days: 365));
        }

        // Update subscription status
        _isSubscribed = true;
        _subscriptionEndDate = endDate;

        // Save to local preferences
        await _saveSubscriptionStatusToPrefs();

        // Save to database if user is logged in
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _saveSubscriptionToDatabase(user.uid);
        }

        _isLoading = false;
        return;
      }

      final purchaseParam = PurchaseParam(productDetails: product);

      // For subscriptions
      bool purchaseStarted = false;

      if (Platform.isAndroid) {
        // For Google Play, use buyNonConsumable for subscriptions
        purchaseStarted =
            await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else if (Platform.isIOS) {
        // For iOS, we'll implement this later
        purchaseStarted =
            await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }

      if (purchaseStarted) {
        _logger.info('Purchase flow started for ${product.id}');
      } else {
        _logger.warning('Failed to start purchase flow for ${product.id}');
        _isLoading = false;
      }

      // The actual purchase result will be delivered via the _purchaseSubscription listener
    } catch (e) {
      _logger.warning('Error purchasing subscription: $e');
      _isLoading = false;
    }
  }

  /// Handle purchase updates from the store
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _logger.info('Purchase pending for ${purchaseDetails.productID}');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        _logger.warning('Purchase error: ${purchaseDetails.error?.message}');
        _isLoading = false;
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Handle successful purchase or restoration
        _handleSuccessfulPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        _logger.info('Purchase canceled');
        _isLoading = false;
      }

      // Complete the purchase to acknowledge to Google Play that we've handled it
      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  /// Handle successful purchase
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    try {
      // Verify purchase with your backend if needed
      // For security, you should validate this receipt with a server

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

      // Save to local preferences
      await _saveSubscriptionStatusToPrefs();

      // Save to database if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _saveSubscriptionToDatabase(user.uid);
      }

      _isLoading = false;
    } catch (e) {
      _logger.warning('Error handling successful purchase: $e');
      _isLoading = false;
    }
  }

  /// Restore purchases from the store
  Future<void> restorePurchases() async {
    try {
      _isLoading = true;
      await _inAppPurchase.restorePurchases();
      _logger.info('Restore purchases initiated');
      // The restored purchases will be delivered via the purchaseStream
    } catch (e) {
      _logger.warning('Error restoring purchases: $e');
      _isLoading = false;
    }
  }

  /// Load subscription status from SharedPreferences
  Future<void> _loadSubscriptionStatusFromPrefs() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _isSubscribed = prefs.getBool(_isSubscribedKey) ?? false;

      final endDateMillis = prefs.getInt(_subscriptionEndDateKey);
      if (endDateMillis != null) {
        _subscriptionEndDate =
            DateTime.fromMillisecondsSinceEpoch(endDateMillis);
      } else {
        _subscriptionEndDate = null;
      }

      _logger.info(
          'Loaded subscription from prefs: $_isSubscribed, $_subscriptionEndDate');
    } catch (e) {
      _logger.warning('Error loading subscription from prefs: $e');
    }
  }

  /// Save subscription status to SharedPreferences
  Future<void> _saveSubscriptionStatusToPrefs() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isSubscribedKey, _isSubscribed);

      if (_subscriptionEndDate != null) {
        await prefs.setInt(
          _subscriptionEndDateKey,
          _subscriptionEndDate!.millisecondsSinceEpoch,
        );
      } else {
        await prefs.remove(_subscriptionEndDateKey);
      }

      _logger.info(
          'Saved subscription to prefs: $_isSubscribed, $_subscriptionEndDate');
    } catch (e) {
      _logger.warning('Error saving subscription to prefs: $e');
    }
  }

  /// Fetch subscription status from Firebase
  Future<void> _fetchSubscriptionFromDatabase(String userId) async {
    try {
      final subscriptionData =
          await _databaseService.getUserFieldData(userId, 'subscriptions');

      if (subscriptionData != null) {
        _isSubscribed = subscriptionData['isSubscribed'] ?? false;

        final endDateMillis = subscriptionData['endDateMillis'];
        if (endDateMillis != null) {
          _subscriptionEndDate = DateTime.fromMillisecondsSinceEpoch(
            endDateMillis,
          );
        } else {
          _subscriptionEndDate = null;
        }

        // Save the fetched data to prefs for offline access
        await _saveSubscriptionStatusToPrefs();

        _logger.info(
            'Fetched subscription from DB: $_isSubscribed, $_subscriptionEndDate');
      }
    } catch (e) {
      _logger.warning('Error fetching subscription from database: $e');
    }
  }

  /// Save subscription status to Firebase
  Future<void> _saveSubscriptionToDatabase(String userId) async {
    try {
      final subscriptionData = {
        'isSubscribed': _isSubscribed,
        'endDateMillis': _subscriptionEndDate?.millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _databaseService.updateUserField(
          userId, 'subscriptions', subscriptionData);
      _logger.info(
          'Saved subscription to DB: $_isSubscribed, $_subscriptionEndDate');
    } catch (e) {
      _logger.warning('Error saving subscription to database: $e');
    }
  }

  /// Cancel subscription
  Future<void> cancelSubscription() async {
    try {
      _isLoading = true;

      // Note: In a real app, this would need to call your backend
      // to cancel the subscription through Google Play Developer API
      // This just updates the local status

      // Mark subscription to end at the current end date (no renewal)
      // User can still use the subscription until the end date
      if (_subscriptionEndDate == null ||
          _subscriptionEndDate!.isBefore(DateTime.now())) {
        _isSubscribed = false;
        _subscriptionEndDate = null;
      }

      // Save to local preferences
      await _saveSubscriptionStatusToPrefs();

      // Save to database if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _saveSubscriptionToDatabase(user.uid);
      }

      _isLoading = false;
    } catch (e) {
      _logger.warning('Error canceling subscription: $e');
      _isLoading = false;
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
}
