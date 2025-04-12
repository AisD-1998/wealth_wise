import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class CurrencyProvider extends ChangeNotifier {
  static const String _currencyKey = 'currency_preference';
  String _currencyCode = 'USD';

  // Map of currency codes to their symbols
  final Map<String, String> _currencySymbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'CAD': 'C\$',
    'AUD': 'A\$',
  };

  // Map of currency codes to their names
  final Map<String, String> _currencyNames = {
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
    'JPY': 'Japanese Yen',
    'CAD': 'Canadian Dollar',
    'AUD': 'Australian Dollar',
  };

  String get currencyCode => _currencyCode;
  String get currencySymbol => _currencySymbols[_currencyCode] ?? '\$';
  List<String> get availableCurrencies => _currencySymbols.keys.toList();

  String getCurrencyName(String code) {
    return _currencyNames[code] ?? '';
  }

  CurrencyProvider() {
    _loadCurrencyPreference();
  }

  Future<void> _loadCurrencyPreference() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _currencyCode = prefs.getString(_currencyKey) ?? 'USD';
    notifyListeners();
  }

  Future<void> setCurrency(String currencyCode) async {
    if (_currencySymbols.containsKey(currencyCode)) {
      _currencyCode = currencyCode;

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currencyKey, currencyCode);

      notifyListeners();
    }
  }

  // Format a number as currency with the current currency symbol
  String format(double amount) {
    return NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 2,
    ).format(amount);
  }

  // Format a number as compact currency (e.g. $1.2K)
  String formatCompact(double amount) {
    return NumberFormat.compactCurrency(
      symbol: currencySymbol,
      decimalDigits: 0,
    ).format(amount);
  }
}
