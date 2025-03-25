import 'package:flutter/material.dart';

class BalanceCard extends StatelessWidget {
  final double balance;
  final double income;
  final double expenses;

  const BalanceCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 360;

    return Card(
      elevation: 0, // Material 3 uses less elevation
      clipBehavior:
          Clip.antiAlias, // Ensures content doesn't overflow rounded corners
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(28), // Material 3 uses more rounded corners
      ),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              colorScheme.tertiary,
            ],
            stops: const [0.0, 1.0],
          ),
          image: DecorationImage(
            image: const AssetImage('assets/images/card_pattern.png'),
            fit: BoxFit.cover,
            opacity: 0.1,
            alignment: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Decorative circle
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 26),
                ),
              ),
            ),
            // Card content
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 20.0 : 28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with subtle opacity
                  Text(
                    'Current Balance',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 217),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Balance amount with large, bold font
                  Text(
                    '\$${balance.toStringAsFixed(2)}',
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Income and Expenses in a row with better spacing
                  Row(
                    children: [
                      // Income indicator
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Income',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 217),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '+\$${income.toStringAsFixed(2)}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Vertical divider
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.white.withValues(alpha: 217),
                      ),

                      // Expenses indicator
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Expenses',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 217),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '-\$${expenses.toStringAsFixed(2)}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
