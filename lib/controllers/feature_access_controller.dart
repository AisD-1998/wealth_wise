import 'package:logging/logging.dart';
import 'package:wealth_wise/models/user.dart';

class FeatureAccessController {
  static final FeatureAccessController _instance =
      FeatureAccessController._internal();
  final Logger _logger = Logger('FeatureAccessController');

  // Maps feature names to their availability status for free users
  final Map<String, bool> _freeFeatures = {
    'basic_budgeting': true,
    'transaction_tracking': true,
    'saving_goals': true,
    'categories': true,
    'dashboard': true,
    'export_data': false,
    'investment_tracking': false,
    'advanced_analytics': false,
    'bill_reminders': false,
    'financial_insights': false,
    'custom_categories': false,
    'unlimited_budgets': false,
    'unlimited_goals': false,
    'ad_free': false,
    'priority_support': false,
  };

  factory FeatureAccessController() {
    return _instance;
  }

  FeatureAccessController._internal();

  /// Checks if a user has access to a specific feature based on their subscription status
  Future<bool> hasAccess(User? user, String featureName) async {
    // If feature doesn't exist in our map, default to false
    if (!_freeFeatures.containsKey(featureName)) {
      _logger.warning('Unknown feature requested: $featureName');
      return false;
    }

    // If feature is free, grant access to everyone
    if (_freeFeatures[featureName] == true) {
      return true;
    }

    // If user is null, they don't have access to premium features
    if (user == null) {
      return false;
    }

    // Check if user has an active subscription
    if (user.isSubscribed) {
      // If subscription end date has passed, treat as expired
      if (user.subscriptionEndDate != null &&
          user.subscriptionEndDate!.isBefore(DateTime.now())) {
        return false;
      }
      return true;
    }

    return false;
  }

  /// Checks if a user has reached their quota for a specific feature
  /// Returns true if they have not exceeded the quota
  bool checkQuota(User? user, String featureType, int currentCount) {
    if (user == null) {
      return false;
    }

    // If user is subscribed, they have unlimited access
    if (user.isSubscribed) {
      return true;
    }

    // Define quota limits for free users
    final Map<String, int> quotaLimits = {
      'budgets': 3,
      'saving_goals': 2,
      'custom_categories': 5,
      'transactions_per_month': 50,
    };

    // If feature type not in map, default to unlimited
    if (!quotaLimits.containsKey(featureType)) {
      return true;
    }

    // Check if current count is within limit
    return currentCount < quotaLimits[featureType]!;
  }

  /// Returns the count limit for a specific feature type
  int getQuotaLimit(String featureType, bool isSubscribed) {
    if (isSubscribed) {
      return -1; // Unlimited
    }

    final Map<String, int> quotaLimits = {
      'budgets': 3,
      'saving_goals': 2,
      'custom_categories': 5,
      'transactions_per_month': 50,
    };

    return quotaLimits[featureType] ?? -1;
  }

  /// Gets a list of premium features
  List<Map<String, dynamic>> getPremiumFeatures() {
    return [
      {
        'name': 'Advanced Analytics',
        'description': 'Get detailed insights into your spending patterns.',
        'icon': 'insights',
        'featureKey': 'advanced_analytics',
      },
      {
        'name': 'Investment Tracking',
        'description': 'Track all your investments in one place.',
        'icon': 'trending_up',
        'featureKey': 'investment_tracking',
      },
      {
        'name': 'Unlimited Budgets',
        'description': 'Create as many budgets as you need.',
        'icon': 'account_balance_wallet',
        'featureKey': 'unlimited_budgets',
      },
      {
        'name': 'Custom Categories',
        'description': 'Create custom categories for your transactions.',
        'icon': 'category',
        'featureKey': 'custom_categories',
      },
      {
        'name': 'Export Data',
        'description': 'Export your financial data for tax purposes.',
        'icon': 'download',
        'featureKey': 'export_data',
      },
      {
        'name': 'Ad-Free Experience',
        'description': 'Enjoy the app without any advertisements.',
        'icon': 'block',
        'featureKey': 'ad_free',
      },
      {
        'name': 'Priority Support',
        'description': 'Get priority customer support.',
        'icon': 'support_agent',
        'featureKey': 'priority_support',
      },
    ];
  }
}
