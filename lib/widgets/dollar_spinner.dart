import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:wealth_wise/theme/app_theme.dart';

class DollarSpinner extends StatefulWidget {
  final double size;
  final Color? primaryColor;
  final Color? secondaryColor;
  final String message;
  final double strokeWidth;

  const DollarSpinner({
    super.key,
    this.size = 60.0,
    this.primaryColor,
    this.secondaryColor,
    this.message = 'Loading...',
    this.strokeWidth = 3.0,
  });

  @override
  State<DollarSpinner> createState() => _DollarSpinnerState();
}

class _DollarSpinnerState extends State<DollarSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutCubic,
      ),
    );

    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0),
        weight: 1,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.primaryColor ?? AppTheme.primaryGreen;
    final secondaryColor = widget.secondaryColor ?? AppTheme.accentMint;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: widget.size,
                    height: widget.size,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      strokeWidth: widget.strokeWidth,
                    ),
                  ),
                  Transform.rotate(
                    angle: _rotationAnimation.value,
                    child: Container(
                      width: widget.size * 0.7,
                      height: widget.size * 0.7,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 51),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        '\$',
                        style: TextStyle(
                          fontSize: widget.size * 0.4,
                          fontWeight: FontWeight.bold,
                          color: secondaryColor,
                          shadows: [
                            Shadow(
                              color: primaryColor.withValues(alpha: 77),
                              blurRadius: 2,
                              offset: const Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (widget.message.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            widget.message,
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
