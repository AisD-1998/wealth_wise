import 'package:flutter/material.dart';
import 'package:wealth_wise/theme/app_theme.dart';
import 'package:wealth_wise/widgets/dollar_spinner.dart';

class LoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;
  final String message;
  final bool useDollarSpinner;

  const LoadingIndicator({
    super.key,
    this.size = 40.0,
    this.color,
    this.strokeWidth = 4.0,
    this.message = 'Loading...',
    this.useDollarSpinner = true, // Default to using the dollar spinner
  });

  @override
  Widget build(BuildContext context) {
    if (useDollarSpinner) {
      return DollarSpinner(
        size: size,
        primaryColor: color ?? AppTheme.primaryGreen,
        secondaryColor: AppTheme.secondaryBlue,
        strokeWidth: strokeWidth,
        message: message,
      );
    }

    // Fallback to standard circular progress indicator
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? AppTheme.primaryGreen,
            ),
            strokeWidth: strokeWidth,
          ),
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
