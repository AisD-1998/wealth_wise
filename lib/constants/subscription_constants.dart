import 'dart:io';
import 'package:flutter/foundation.dart';

class SubscriptionConstants {
  SubscriptionConstants._();

  // Product IDs
  // TODO(account-setup): Verify these match your Google Play Console product IDs
  static const String monthlyProductId = 'wealthwise_monthly';
  static const String annualProductId = 'wealthwise_annual';

  // Fallback pricing (used when store products fail to load)
  static const double monthlyFallbackPrice = 3.99;
  static const double annualFallbackPrice = 19.99;
  static const String fallbackCurrency = 'USD';
  static const String monthlyFallbackPriceDisplay = 'USD 3.99';
  static const String annualFallbackPriceDisplay = 'USD 19.99';
  static const String annualDiscountLabel = '58% OFF';

  // SharedPreferences keys
  static const String prefIsSubscribed = 'isSubscribed';
  static const String prefEndDateMillis = 'subscriptionEndDateMillis';
  static const String prefProductId = 'subscriptionProductId';
  static const String prefAppLoadCount = 'appLoadCount';

  // Legacy SharedPreferences keys (from old BillingService, for migration)
  static const String legacyPrefIsSubscribed = 'is_subscribed';
  static const String legacyPrefEndDate = 'subscription_end_date';
  static const String legacyPrefProductId = 'subscription_product_id';

  // AdMob IDs
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  // TODO(account-setup): Replace with production AdMob ad unit IDs
  static const String _prodBannerAdUnitId = 'ca-app-pub-XXXXX/YYYYY';
  static const String _prodInterstitialAdUnitId = 'ca-app-pub-XXXXX/ZZZZZ';

  static String get bannerAdUnitId =>
      kDebugMode ? _testBannerAdUnitId : _prodBannerAdUnitId;
  static String get interstitialAdUnitId =>
      kDebugMode ? _testInterstitialAdUnitId : _prodInterstitialAdUnitId;

  // Platform subscription management URLs (for cancel flow)
  static String get subscriptionManagementUrl => Platform.isIOS
      ? 'https://apps.apple.com/account/subscriptions'
      : 'https://play.google.com/store/account/subscriptions';
}
