import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wealth_wise/constants/subscription_constants.dart';
import 'package:wealth_wise/services/database_service.dart';
import 'package:logging/logging.dart';

class SubscriptionProvider extends ChangeNotifier {
  final Logger _logger = Logger('SubscriptionProvider');
  final DatabaseService _databaseService = DatabaseService();
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;

  // Available products from the store (or fallback)
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

  // App load counter for ad frequency
  int _appLoadCount = 0;
  int get appLoadCount => _appLoadCount;

  // Initialization guard
  bool _hasInitialized = false;

  // Timeout for loading products
  static const Duration _initTimeout = Duration(seconds: 10);

  /// Initialize the subscription provider.
  /// Loads cached status, syncs with Firestore, sets up IAP stream,
  /// loads products, and creates ads if not subscribed.
  Future<void> initialize() async {
    if (_hasInitialized) return;
    _hasInitialized = true;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _initializeMobileAds();
      await _migrateLegacyPrefs();
      await _loadSubscriptionStatusFromPrefs();
      await _syncSubscriptionWithFirestore();
      await _clearExpiredSubscription();
      await _incrementAppLoadCount();
      _startInitTimeout();
      _setupPurchaseStream();
      await _loadProducts();
      _initializeAdsIfNeeded();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _logger.warning('Error initializing subscription provider: $e');
      _errorMessage = 'Failed to initialize subscription services';
      _isLoading = false;
      if (_products.isEmpty) _createFallbackProducts();
      notifyListeners();
    }
  }

  Future<void> _initializeMobileAds() async {
    try {
      await MobileAds.instance.initialize();
    } catch (adError) {
      _logger.warning('MobileAds init error (may be already initialized): $adError');
    }
  }

  Future<void> _syncSubscriptionWithFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _fetchSubscriptionFromDatabase(user.uid);
    }
  }

  Future<void> _clearExpiredSubscription() async {
    if (_subscriptionEndDate == null ||
        !_subscriptionEndDate!.isBefore(DateTime.now())) {
      return;
    }
    _isSubscribed = false;
    _subscriptionEndDate = null;
    await _saveSubscriptionStatusToPrefs();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _saveSubscriptionToDatabase(user.uid);
    }
  }

  void _startInitTimeout() {
    Timer(_initTimeout, () {
      if (_isLoading) {
        _logger.warning('Subscription initialization timed out');
        _isLoading = false;
        if (_products.isEmpty) _createFallbackProducts();
        notifyListeners();
      }
    });
  }

  void _setupPurchaseStream() {
    final purchaseStream = _inAppPurchase.purchaseStream;
    _purchaseSubscription?.cancel();
    _purchaseSubscription = purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (error) {
        _logger.warning('Purchase stream error: $error');
      },
    );
  }

  void _initializeAdsIfNeeded() {
    if (_isSubscribed) return;
    try {
      _createBannerAd();
      _createInterstitialAd();
    } catch (adError) {
      _logger.warning('Error creating ads: $adError');
    }
  }

  // ─── SharedPrefs Migration ───────────────────────────────────────────

  /// Migrate old BillingService snake_case SharedPrefs keys to new format.
  /// Runs once; old keys are deleted after migration.
  Future<void> _migrateLegacyPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final oldIsSubscribed =
          prefs.getBool(SubscriptionConstants.legacyPrefIsSubscribed);
      if (oldIsSubscribed == null) return; // No legacy data

      // Only migrate if new keys don't already exist
      if (prefs.getBool(SubscriptionConstants.prefIsSubscribed) == null) {
        await prefs.setBool(
            SubscriptionConstants.prefIsSubscribed, oldIsSubscribed);

        final oldEndDate =
            prefs.getInt(SubscriptionConstants.legacyPrefEndDate);
        if (oldEndDate != null) {
          await prefs.setInt(
              SubscriptionConstants.prefEndDateMillis, oldEndDate);
        }

        final oldProductId =
            prefs.getString(SubscriptionConstants.legacyPrefProductId);
        if (oldProductId != null) {
          await prefs.setString(
              SubscriptionConstants.prefProductId, oldProductId);
        }
      }

      // Delete old keys
      await prefs.remove(SubscriptionConstants.legacyPrefIsSubscribed);
      await prefs.remove(SubscriptionConstants.legacyPrefEndDate);
      await prefs.remove(SubscriptionConstants.legacyPrefProductId);

      _logger.info('Legacy SharedPrefs migration complete');
    } catch (e) {
      _logger.warning('Error migrating legacy prefs: $e');
    }
  }

  // ─── Product Loading ─────────────────────────────────────────────────

  /// Load in-app purchase products from the store.
  Future<void> _loadProducts() async {
    try {
      final available = await _inAppPurchase.isAvailable();
      if (!available) {
        _logger.warning('In-app purchase is not available');
        _createFallbackProducts();
        return;
      }

      final productIds = <String>{
        SubscriptionConstants.monthlyProductId,
        SubscriptionConstants.annualProductId,
      };

      final ProductDetailsResponse response =
          await _inAppPurchase.queryProductDetails(productIds);

      if (response.error != null) {
        _logger.warning('Error querying products: ${response.error}');
        _createFallbackProducts();
        return;
      }

      if (response.notFoundIDs.isNotEmpty) {
        _logger.warning('Products not found: ${response.notFoundIDs}');
      }

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

  /// Create fallback products for UI when store products fail to load.
  /// These are display-only and cannot be purchased.
  void _createFallbackProducts() {
    _logger.info('Creating fallback products');
    _products = [
      ProductDetails(
        id: SubscriptionConstants.monthlyProductId,
        title: 'Monthly Premium',
        description: 'Unlimited access for one month',
        price: SubscriptionConstants.monthlyFallbackPriceDisplay,
        rawPrice: SubscriptionConstants.monthlyFallbackPrice,
        currencyCode: SubscriptionConstants.fallbackCurrency,
      ),
      ProductDetails(
        id: SubscriptionConstants.annualProductId,
        title: 'Annual Premium',
        description:
            'Unlimited access for one year (${SubscriptionConstants.annualDiscountLabel})',
        price: SubscriptionConstants.annualFallbackPriceDisplay,
        rawPrice: SubscriptionConstants.annualFallbackPrice,
        currencyCode: SubscriptionConstants.fallbackCurrency,
      ),
    ];
  }

  // ─── Purchase Flow ───────────────────────────────────────────────────

  /// Start a subscription purchase via the platform billing dialog.
  Future<void> buySubscription(ProductDetails product) async {
    try {
      _logger.info('Attempting to purchase ${product.id}');
      _isLoading = true;
      notifyListeners();

      // Verify the store is available
      final available = await _inAppPurchase.isAvailable();
      if (!available) {
        _logger.warning('Store not available for purchase');
        _errorMessage = 'Store is not available. Please try again later.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Find the real product in our loaded list
      ProductDetails validProduct;
      try {
        validProduct = _products.firstWhere((p) => p.id == product.id);
      } catch (_) {
        // Reload and retry
        await _loadProducts();
        try {
          validProduct = _products.firstWhere((p) => p.id == product.id);
        } catch (_) {
          _logger.severe('Product not available: ${product.id}');
          _errorMessage = 'Product not available. Please try again later.';
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      final purchaseParam = PurchaseParam(productDetails: validProduct);
      final purchaseStarted =
          await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      if (purchaseStarted) {
        _logger.info('Purchase flow started for ${product.id}');
      } else {
        _logger.warning('Failed to start purchase flow for ${product.id}');
        _isLoading = false;
        notifyListeners();
      }

      // Safety timeout: exit loading if purchase listener doesn't fire
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

  /// Handle purchase updates from the platform billing stream.
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    _logger.info('Received ${purchaseDetailsList.length} purchase updates');

    for (final purchase in purchaseDetailsList) {
      _logger.info(
          'Purchase update: ${purchase.productID} status=${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _logger.info('Purchase pending for ${purchase.productID}');
          break;
        case PurchaseStatus.error:
          _logger.warning('Purchase error: ${purchase.error?.message}');
          _isLoading = false;
          notifyListeners();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _handleSuccessfulPurchase(purchase);
          break;
        case PurchaseStatus.canceled:
          _logger.info('Purchase canceled');
          _isLoading = false;
          notifyListeners();
          break;
      }

      // Critical: complete the purchase to finalize the transaction
      if (purchase.pendingCompletePurchase) {
        _logger.info('Completing purchase for ${purchase.productID}');
        _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  /// Handle a successful purchase or restored purchase.
  /// Verifies the purchase, sets subscription status, saves to prefs + Firestore.
  Future<void> _handleSuccessfulPurchase(PurchaseDetails purchase) async {
    _logger.info('Handling successful purchase: ${purchase.productID}');

    try {
      // Verify the purchase is valid
      final isValid = await _verifyPurchase(purchase);
      if (!isValid) {
        _logger.warning('Purchase verification failed: ${purchase.productID}');
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Determine subscription end date
      DateTime endDate;
      if (purchase.productID == SubscriptionConstants.monthlyProductId) {
        endDate = DateTime.now().add(const Duration(days: 30));
      } else if (purchase.productID == SubscriptionConstants.annualProductId) {
        endDate = DateTime.now().add(const Duration(days: 365));
      } else {
        endDate = DateTime.now().add(const Duration(days: 30));
      }

      _isSubscribed = true;
      _subscriptionEndDate = endDate;

      // Save locally and remotely
      await _saveSubscriptionStatusToPrefs(purchase.productID);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _saveSubscriptionToDatabase(user.uid, purchase.productID);
      }

      // Dispose ads since user is now subscribed
      _disposeBannerAd();

      _isLoading = false;
      notifyListeners();

      _logger.info('Successfully processed purchase: ${purchase.productID}');
    } catch (e) {
      _logger.severe('Error handling successful purchase: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Verify that a purchase is valid via platform-specific checks.
  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    if (Platform.isAndroid) {
      final googlePurchase = purchase as GooglePlayPurchaseDetails;
      if (googlePurchase.billingClientPurchase.purchaseToken.isEmpty) {
        return false;
      }
      // TODO(account-setup): Add server-side verification for production
      return true;
    } else if (Platform.isIOS) {
      final appStorePurchase = purchase as AppStorePurchaseDetails;
      if (appStorePurchase.verificationData.serverVerificationData.isEmpty) {
        return false;
      }
      // TODO(account-setup): Add server-side verification for production
      return true;
    }
    return false;
  }

  /// Restore previous purchases from the platform store.
  Future<void> restorePurchases() async {
    try {
      _isLoading = true;
      notifyListeners();
      await _inAppPurchase.restorePurchases();
      _logger.info('Restore purchases initiated');
      // Results arrive via _handlePurchaseUpdates stream
    } catch (e) {
      _logger.warning('Error restoring purchases: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Open the platform's subscription management page.
  /// This is how users cancel — we don't cancel locally.
  Future<void> openSubscriptionManagement() async {
    try {
      final url = SubscriptionConstants.subscriptionManagementUrl;
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      _logger.warning('Error opening subscription management: $e');
    }
  }

  // ─── Local Storage ───────────────────────────────────────────────────

  Future<void> _loadSubscriptionStatusFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _isSubscribed =
          prefs.getBool(SubscriptionConstants.prefIsSubscribed) ?? false;

      final endDateMillis =
          prefs.getInt(SubscriptionConstants.prefEndDateMillis);
      if (endDateMillis != null) {
        _subscriptionEndDate =
            DateTime.fromMillisecondsSinceEpoch(endDateMillis);

        if (_subscriptionEndDate!.isBefore(DateTime.now())) {
          _isSubscribed = false;
          _subscriptionEndDate = null;
          await _saveSubscriptionStatusToPrefs();
        }
      }
    } catch (e) {
      _logger.warning('Error loading subscription from prefs: $e');
    }
  }

  Future<void> _saveSubscriptionStatusToPrefs([String? productId]) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(
          SubscriptionConstants.prefIsSubscribed, _isSubscribed);

      if (_subscriptionEndDate != null) {
        await prefs.setInt(SubscriptionConstants.prefEndDateMillis,
            _subscriptionEndDate!.millisecondsSinceEpoch);
        if (productId != null) {
          await prefs.setString(
              SubscriptionConstants.prefProductId, productId);
        }
      } else {
        await prefs.remove(SubscriptionConstants.prefEndDateMillis);
        await prefs.remove(SubscriptionConstants.prefProductId);
      }
    } catch (e) {
      _logger.warning('Error saving subscription to prefs: $e');
    }
  }

  // ─── Firestore Storage ───────────────────────────────────────────────

  Future<void> _fetchSubscriptionFromDatabase(String userId) async {
    try {
      final userData = await _databaseService.getUserData(userId);
      if (userData == null) return;

      if (userData.isSubscribed &&
          userData.subscriptionEndDate != null &&
          userData.subscriptionEndDate!.isAfter(DateTime.now())) {
        _isSubscribed = true;
        _subscriptionEndDate = userData.subscriptionEndDate;
        await _saveSubscriptionStatusToPrefs();
      } else if (userData.isSubscribed &&
          userData.subscriptionEndDate != null &&
          userData.subscriptionEndDate!.isBefore(DateTime.now())) {
        // Subscription expired — clear it
        _isSubscribed = false;
        _subscriptionEndDate = null;
        await _saveSubscriptionStatusToPrefs();
        await _saveSubscriptionToDatabase(userId);
      }
    } catch (e) {
      _logger.warning('Error fetching subscription from database: $e');
    }
  }

  Future<void> _saveSubscriptionToDatabase(String userId,
      [String? productId]) async {
    try {
      String? subscriptionType;
      if (_isSubscribed && productId != null) {
        subscriptionType = productId.contains('annual') ? 'annual' : 'monthly';
      }

      final data = <String, dynamic>{
        'isSubscribed': _isSubscribed,
        'subscriptionType': subscriptionType,
        'subscriptionEndDate': _subscriptionEndDate,
      };

      for (final entry in data.entries) {
        await _databaseService.updateUserField(userId, entry.key, entry.value);
      }
    } catch (e) {
      _logger.warning('Error saving subscription to database: $e');
    }
  }

  // ─── Ad Management ───────────────────────────────────────────────────

  Future<void> _incrementAppLoadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _appLoadCount =
          (prefs.getInt(SubscriptionConstants.prefAppLoadCount) ?? 0) + 1;
      await prefs.setInt(SubscriptionConstants.prefAppLoadCount, _appLoadCount);
    } catch (e) {
      _logger.warning('Error incrementing app load count: $e');
    }
  }

  void _createBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: SubscriptionConstants.bannerAdUnitId,
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

  void _createInterstitialAd() {
    InterstitialAd.load(
      adUnitId: SubscriptionConstants.interstitialAdUnitId,
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

  void showInterstitialAd() {
    if (_isInterstitialAdReady && !_isSubscribed) {
      _interstitialAd?.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _createInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          _logger.warning('Failed to show interstitial ad: $error');
          ad.dispose();
          _createInterstitialAd();
        },
      );
      _interstitialAd?.show();
      _isInterstitialAdReady = false;
    }
  }

  void _disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdReady = false;
  }

  /// Whether ads should be shown. Purely synchronous — no async race conditions.
  bool shouldShowAds() {
    if (_isSubscribed) return false;
    return _appLoadCount % 3 == 0;
  }

  // ─── Utility ─────────────────────────────────────────────────────────

  /// Force exit loading state when IAP initialization hangs.
  void forceExitLoadingState() {
    if (_isLoading) {
      _logger.warning('Forcing exit from loading state');
      _isLoading = false;
      if (_products.isEmpty) _createFallbackProducts();
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
