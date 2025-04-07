import 'package:flutter/material.dart';
import 'package:wealth_wise/widgets/dollar_spinner.dart';

/// Utility class for loading animations across the app
class LoadingAnimationUtils {
  /// Creates a small dollar spinner suitable for SnackBars and inline indicators
  static Widget smallDollarSpinner({
    double size = 20.0,
    Color? primaryColor,
    Color? secondaryColor,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: DollarSpinner(
        size: size,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
        message: '',
        strokeWidth: 2.0,
      ),
    );
  }

  /// Creates a loading SnackBar with the dollar spinner animation
  static SnackBar loadingSnackBar(String message) {
    return SnackBar(
      content: Row(
        children: [
          smallDollarSpinner(),
          const SizedBox(width: 16),
          Text(message),
        ],
      ),
      duration: const Duration(seconds: 5),
    );
  }

  /// Creates a dollar spinner overlay with a semi-transparent background
  static Widget createDollarOverlay({
    String message = 'Loading...',
    double size = 80.0,
  }) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Card(
          elevation: 4.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 32.0, horizontal: 40.0),
            child: DollarSpinner(
              size: size,
              message: message,
            ),
          ),
        ),
      ),
    );
  }
}
