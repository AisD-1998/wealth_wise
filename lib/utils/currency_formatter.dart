import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:wealth_wise/providers/currency_provider.dart';

// Static class for legacy support
class CurrencyFormatter {
  // For backward compatibility
  static String format(double amount, {String? symbol}) {
    return NumberFormat.currency(
      symbol: symbol ?? '\$',
      decimalDigits: 2,
    ).format(amount);
  }

  // For backward compatibility
  static String formatCompact(double amount, {String? symbol}) {
    return NumberFormat.compactCurrency(
      symbol: symbol ?? '\$',
      decimalDigits: 0,
    ).format(amount);
  }

  // For backward compatibility
  static String formatWithSymbol(double amount, String symbol) {
    return NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    ).format(amount);
  }

  // Get the current currency symbol from context
  static String formatWithContext(BuildContext context, double amount) {
    final currencyProvider =
        Provider.of<CurrencyProvider>(context, listen: false);
    return currencyProvider.format(amount);
  }

  // Get the compact format with currency symbol from context
  static String formatCompactWithContext(BuildContext context, double amount) {
    final currencyProvider =
        Provider.of<CurrencyProvider>(context, listen: false);
    return currencyProvider.formatCompact(amount);
  }
}
