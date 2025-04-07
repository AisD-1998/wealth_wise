import 'package:flutter/material.dart';
import 'package:wealth_wise/widgets/dollar_spinner.dart';
import 'package:wealth_wise/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryGreen,
              Color(0xFF1B5E20), // Darker green
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo or app name
              const Text(
                'WealthWise',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Custom loading indicator
              const DollarSpinner(
                size: 80.0,
                primaryColor: Colors.white,
                secondaryColor: AppTheme.accentMint,
                strokeWidth: 3.0,
                message: '',
              ),
              const SizedBox(height: 40),
              // Loading text
              const Text(
                'Smart Finance Management',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
