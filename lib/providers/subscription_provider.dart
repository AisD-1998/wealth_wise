import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wealth_wise/services/database_service.dart';
import 'package:logging/logging.dart';

class SubscriptionProvider extends ChangeNotifier {
  // Logger
  final Logger _logger = Logger('SubscriptionProvider');

  // Database service for storing subscription status
  final DatabaseService _databaseService = DatabaseService();

  // In-App Purchase instance
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  // Subscription product IDs
  static const String _monthlySubscriptionId =
      'wealthwise_monthly'; // Real product ID
  static const String _annualSubscriptionId =
      'wealthwise_annual'; // Real product ID

  // Track available products
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

  // Banner ad
  BannerAd? _bannerAd;
  BannerAd? get bannerAd => _bannerAd;
  bool _isBannerAdReady = false;
  bool get isBannerAdReady => _isBannerAdReady;

  // Interstitial ad
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  bool get isInterstitialAdReady => _isInterstitialAdReady;

  // Purchase stream subscription
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  // Store info about app loads (to show ads periodically, not on every screen)
  int _appLoadCount = 0;
  int get appLoadCount => _appLoadCount;

  // Test ad units for development
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  // Flag to track if initialization has been called
  bool _hasInitialized = false;

  // Timeout for loading products
  static const Duration _initTimeout = Duration(seconds: 10);

  // Initialize subscription provider
  Future<void> initialize() async {
    // Prevent multiple initializations
    if (_hasInitialized) {
      return;
    }
    _hasInitialized = true;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Initialize mobile ads SDK (skip if already initialized in main.dart)
      try {
        await MobileAds.instance.initialize();
      } catch (adError) {
        _logger.warning(
            'MobileAds initialization error (may be already initialized): $adError');
        // Continue execution even if ad initialization fails
      }

      // Load subscription status from local storage first (for quick access)
      await _loadSubscriptionStatusFromPrefs();

      // Then try to get the latest status from the server
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _fetchSubscriptionFromDatabase(user.uid);
      }

      // Increment app load count for ad frequency management
      await _incrementAppLoadCount();

      // Setup timeout to prevent infinite loading
      Timer(_initTimeout, () {
        if (_isLoading) {
          _logger.warning('Subscription initialization timed out');
          _isLoading = false;

          // Create fallback products for UI if none loaded
          if (_products.isEmpty) {
            _createFallbackProducts();
          }

          notifyListeners();
        }
      });

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

      // Initialize ads if user is not subscribed
      if (!_isSubscribed) {
        try {
          _createBannerAd();
          _createInterstitialAd();
        } catch (adError) {
          _logger.warning('Error creating ads: $adError');
          // Continue execution even if ad creation fails
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _logger.warning('Error initializing subscription provider: $e');
      _errorMessage = 'Failed to initialize subscription services';
      _isLoading = false;

      // Create fallback products for UI if none loaded
      if (_products.isEmpty) {
        _createFallbackProducts();
      }

      notifyListeners();
    }
  }

  // Create fallback products for UI when real products fail to load
  void _createFallbackProducts() {
    _logger.info('Creating fallback products');
    // Use our mock products instead of creating inline
    _products = [
      _createMockProduct(
        'wealthwise_monthly',
        'Monthly Premium',
        'Unlimited access for one month',
        'USD',
        3.99,
      ),
      _createMockProduct(
        'wealthwise_annual',
        'Annual Premium',
        'Unlimited access for one year (58% discount)',
        'USD',
        19.99,
      ),
    ];
  }

  // Helper method to create mock product for display purposes only
  ProductDetails _createMockProduct(
    String id,
    String title,
    String description,
    String currencyCode,
    double price,
  ) {
    return ProductDetails(
      id: id,
      title: title,
      description: description,
      price: '$currencyCode $price',
      rawPrice: price,
      currencyCode: currencyCode,
    );
  }

  // Load in-app purchase products
  Future<void> _loadProducts() async {
    try {
      final available = await _inAppPurchase.isAvailable();
      if (!available) {
        _logger.warning('In-app purchase is not available');
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

      notifyListeners();
    } catch (e) {
      _logger.warning('Error loading products: $e');
      _createFallbackProducts();
    }
  }

  // Handle purchase updates
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show a dialog or indicator for pending purchase
        _logger.info('Purchase pending for ${purchaseDetails.productID}');
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // Handle error
        _logger.warning('Purchase error: ${purchaseDetails.error?.message}');
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Handle successful purchase or restoration
        _handleSuccessfulPurchase(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        _logger.info('Purchase canceled');
      }

      // Complete the purchase
      if (purchaseDetails.pendingCompletePurchase) {
        _inAppPurchase.completePurchase(purchaseDetails);
      }
    }
  }

  // Handle successful purchase
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    // Verify purchase on your server if needed

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

    // Dispose ads if they exist
    _disposeBannerAd();

    notifyListeners();
  }

  // Buy subscription
  Future<void> buySubscription(ProductDetails product) async {
    try {
      _logger.info('Attempting to purchase ${product.id}');

      // Show a loading state
      _isLoading = true;
      notifyListeners();

      final purchaseParam = PurchaseParam(productDetails: product);

      // For subscriptions
      bool purchaseStarted = false;

      if (Platform.isAndroid) {
        purchaseStarted =
            await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else if (Platform.isIOS) {
        purchaseStarted =
            await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }

      if (purchaseStarted) {
        _logger.info('Purchase flow started for ${product.id}');
      } else {
        _logger.warning('Failed to start purchase flow for ${product.id}');
        _isLoading = false;
        notifyListeners();
      }

      // Note: actual purchase result will be delivered via the _purchaseSubscription listener
      // in _handlePurchaseUpdates, which will update the subscription status

      // In case the purchase listener doesn't trigger after a reasonable time,
      // exit loading state after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        if (_isLoading) {
          _logger.warning('Purchase timeout, exiting loading state');
          _isLoading = false;
          notifyListeners();
        }
      });
    } catch (e) {
      _logger.warning('Error purchasing subscription: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Restore purchases
  Future<void> restorePurchases() async {
    try {
      await _inAppPurchase.restorePurchases();
      _logger.info('Restore purchases initiated');
    } catch (e) {
      _logger.warning('Error restoring purchases: $e');
    }
  }

  // Load subscription status from local prefs for quick access on app start
  Future<void> _loadSubscriptionStatusFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get subscription status
      _isSubscribed = prefs.getBool('isSubscribed') ?? false;

      // Get subscription end date
      final endDateMillis = prefs.getInt('subscriptionEndDateMillis');
      if (endDateMillis != null) {
        _subscriptionEndDate =
            DateTime.fromMillisecondsSinceEpoch(endDateMillis);

        // Check if subscription has expired
        if (_subscriptionEndDate!.isBefore(DateTime.now())) {
          _isSubscribed = false;
          _subscriptionEndDate = null;
          await _saveSubscriptionStatusToPrefs(); // Update prefs with expired status
        }
      }
    } catch (e) {
      _logger.warning('Error loading subscription from prefs: $e');
    }
  }

  // Save subscription status to prefs
  Future<void> _saveSubscriptionStatusToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save subscription status
      await prefs.setBool('isSubscribed', _isSubscribed);

      // Save subscription end date
      if (_subscriptionEndDate != null) {
        await prefs.setInt('subscriptionEndDateMillis',
            _subscriptionEndDate!.millisecondsSinceEpoch);
      } else {
        await prefs.remove('subscriptionEndDateMillis');
      }
    } catch (e) {
      _logger.warning('Error saving subscription to prefs: $e');
    }
  }

  // Fetch subscription status from database
  Future<void> _fetchSubscriptionFromDatabase(String userId) async {
    try {
      final subscriptionData =
          await _databaseService.getUserFieldData(userId, 'subscriptions');

      if (subscriptionData != null &&
          subscriptionData is Map<String, dynamic>) {
        // Update subscription status from database
        final endDateMillis = subscriptionData['endDateMillis'] as int?;

        if (endDateMillis != null) {
          final endDate = DateTime.fromMillisecondsSinceEpoch(endDateMillis);

          // Check if the subscription is still valid
          if (endDate.isAfter(DateTime.now())) {
            _isSubscribed = true;
            _subscriptionEndDate = endDate;
          } else {
            _isSubscribed = false;
            _subscriptionEndDate = null;
          }

          // Update local prefs with the latest data
          await _saveSubscriptionStatusToPrefs();
        }
      }
    } catch (e) {
      _logger.warning('Error fetching subscription from database: $e');
    }
  }

  // Save subscription to database
  Future<void> _saveSubscriptionToDatabase(String userId) async {
    try {
      if (!_isSubscribed || _subscriptionEndDate == null) {
        await _databaseService.removeField(userId, 'subscriptions');
        return;
      }

      final subscriptionData = {
        'isSubscribed': _isSubscribed,
        'endDateMillis': _subscriptionEndDate!.millisecondsSinceEpoch,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      await _databaseService.updateUserField(
          userId, 'subscriptions', subscriptionData);
    } catch (e) {
      _logger.warning('Error saving subscription to database: $e');
    }
  }

  // Increment app load count for managing ad frequency
  Future<void> _incrementAppLoadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _appLoadCount = (prefs.getInt('appLoadCount') ?? 0) + 1;
      await prefs.setInt('appLoadCount', _appLoadCount);
    } catch (e) {
      _logger.warning('Error incrementing app load count: $e');
    }
  }

  // Create banner ad
  void _createBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _testBannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _isBannerAdReady = true;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          _logger.warning('Banner ad failed to load: $error');
          ad.dispose();
          _bannerAd = null;
          _isBannerAdReady = false;
          notifyListeners();
        },
      ),
    );

    _bannerAd?.load();
  }

  // Create interstitial ad
  void _createInterstitialAd() {
    InterstitialAd.load(
      adUnitId: _testInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _logger.warning('Interstitial ad failed to load: $error');
          _isInterstitialAdReady = false;
          notifyListeners();
        },
      ),
    );
  }

  // Show interstitial ad
  void showInterstitialAd() {
    if (_isInterstitialAdReady && !_isSubscribed) {
      _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _createInterstitialAd(); // Create a new ad for next time
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          _logger.warning('Failed to show interstitial ad: $error');
          ad.dispose();
          _createInterstitialAd(); // Create a new ad for next time
        },
      );
      _interstitialAd?.show();
      _isInterstitialAdReady = false;
    }
  }

  // Dispose banner ad
  void _disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdReady = false;
  }

  // Should show ads based on app load count for better user experience
  bool shouldShowAds() {
    // Don't show ads if user is subscribed
    if (_isSubscribed) return false;

    // Show ads on every 3rd app load to avoid overwhelming new users
    return _appLoadCount % 3 == 0;
  }

  // For development/testing - creates a temporary mock subscription
  Future<void> createTemporaryMockSubscription() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Simulate subscription purchase
      _isSubscribed = true;
      _subscriptionEndDate = DateTime.now().add(const Duration(days: 30));

      // Save to local preferences
      await _saveSubscriptionStatusToPrefs();

      // Save to database if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _saveSubscriptionToDatabase(user.uid);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _logger.warning('Error creating mock subscription: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set subscription status manually (for UI testing or admin functions)
  Future<void> setSubscriptionStatus(
      bool isSubscribed, DateTime endDate) async {
    try {
      _isLoading = true;
      notifyListeners();

      _isSubscribed = isSubscribed;
      _subscriptionEndDate = endDate;

      // Save to local preferences
      await _saveSubscriptionStatusToPrefs();

      // Save to database if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _saveSubscriptionToDatabase(user.uid);
      }

      // Dispose ads if subscribed
      if (isSubscribed) {
        _disposeBannerAd();
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _logger.warning('Error setting subscription status: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cancel subscription
  Future<void> cancelSubscription() async {
    try {
      _isLoading = true;
      notifyListeners();

      // In a real app, this would call your server to cancel the subscription
      // We just update the status locally in this demo

      // Mark subscription to end at the current end date (no renewal)
      // We don't immediately cancel the subscription - user can use it until the end date

      // If there's no current valid subscription, just reset everything
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
      notifyListeners();
    } catch (e) {
      _logger.warning('Error canceling subscription: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // Force exit loading state - useful when IAP initialization hangs
  void forceExitLoadingState() {
    if (_isLoading) {
      _logger.warning('Forcing exit from loading state');
      _isLoading = false;

      // Create fallback products if needed
      if (_products.isEmpty) {
        _createFallbackProducts();
      }

      notifyListeners();
    }
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
}
