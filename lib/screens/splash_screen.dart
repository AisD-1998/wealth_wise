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
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo or app name
              Text(
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
              SizedBox(height: 40),
              // Custom loading indicator
              DollarSpinner(
                size: 80.0,
                primaryColor: Colors.white,
                secondaryColor: AppTheme.accentMint,
                strokeWidth: 3.0,
                message: '',
              ),
              SizedBox(height: 40),
              // Loading text
              Text(
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
