import 'package:flutter/material.dart';

class SavingGoalsScreen extends StatelessWidget {
  const SavingGoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saving Goals')),
      body: const Center(child: Text('Saving goals will be shown here')),
    );
  }
}
