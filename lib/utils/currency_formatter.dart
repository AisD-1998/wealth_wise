import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount) {
    return NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    ).format(amount);
  }

  static String formatCompact(double amount) {
    return NumberFormat.compactCurrency(
      symbol: '\$',
      decimalDigits: 0,
    ).format(amount);
  }

  static String formatWithSymbol(double amount, String symbol) {
    return NumberFormat.currency(
      symbol: symbol,
      decimalDigits: 2,
    ).format(amount);
  }
}
