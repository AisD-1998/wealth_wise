import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/models/user_preferences.dart';
import 'package:wealth_wise/providers/user_preferences_provider.dart';
import 'package:wealth_wise/theme/app_theme.dart';

class PersonalizationScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const PersonalizationScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 4;
  bool _canContinue = false;

  @override
  void initState() {
    super.initState();

    // Load any previously saved temp preferences
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    // Load preferences without using BuildContext in async gap
    await Provider.of<UserPreferencesProvider>(context, listen: false)
        .loadTempPreferencesFromLocal();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Save preferences to local storage before completing
      Provider.of<UserPreferencesProvider>(context, listen: false)
          .saveTempPreferencesToLocal()
          .then((_) => widget.onComplete());
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Personalize Your Experience'),
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousPage,
              )
            : null,
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                  _updateCanContinue();
                });
              },
              children: [
                _buildFinancialGoalPage(),
                _buildIncomeRangePage(),
                _buildExpertisePage(),
                _buildAdditionalPreferencesPage(),
              ],
            ),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Step ${_currentPage + 1}/$_totalPages',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                '${((_currentPage + 1) / _totalPages * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentPage + 1) / _totalPages,
            backgroundColor: Colors.grey[200],
            color: AppTheme.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialGoalPage() {
    return Consumer<UserPreferencesProvider>(builder: (context, provider, _) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What\'s your primary financial goal?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll tailor your experience based on what matters most to you.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ...FinancialGoal.values
                        .map((goal) => _buildGoalOption(goal)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildGoalOption(FinancialGoal goal) {
    return Consumer<UserPreferencesProvider>(builder: (context, provider, _) {
      final isSelected = provider.tempPrimaryGoal == goal;

      IconData iconData;
      switch (goal) {
        case FinancialGoal.saveMoney:
          iconData = Icons.savings;
          break;
        case FinancialGoal.payOffDebt:
          iconData = Icons.credit_card_off;
          break;
        case FinancialGoal.investForFuture:
          iconData = Icons.trending_up;
          break;
        case FinancialGoal.budgetBetter:
          iconData = Icons.account_balance_wallet;
          break;
        case FinancialGoal.trackExpenses:
          iconData = Icons.receipt_long;
          break;
        case FinancialGoal.other:
          iconData = Icons.more_horiz;
          break;
      }

      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: isSelected ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            provider.setTempPrimaryGoal(goal);
            _updateCanContinue();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    iconData,
                    color: isSelected ? AppTheme.primaryGreen : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        UserPreferences.financialGoalToString(goal),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 4),
                      _buildGoalDescription(goal),
                    ],
                  ),
                ),
                Radio(
                  value: goal,
                  groupValue: provider.tempPrimaryGoal,
                  onChanged: (FinancialGoal? value) {
                    if (value != null) {
                      provider.setTempPrimaryGoal(value);
                      _updateCanContinue();
                    }
                  },
                  activeColor: AppTheme.primaryGreen,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildGoalDescription(FinancialGoal goal) {
    String description;
    switch (goal) {
      case FinancialGoal.saveMoney:
        description = 'Build an emergency fund or save for specific goals';
        break;
      case FinancialGoal.payOffDebt:
        description =
            'Reduce and eliminate loans, credit cards and other debts';
        break;
      case FinancialGoal.investForFuture:
        description = 'Grow your wealth through various investment strategies';
        break;
      case FinancialGoal.budgetBetter:
        description = 'Create and stick to a realistic spending plan';
        break;
      case FinancialGoal.trackExpenses:
        description =
            'Monitor where your money goes to reduce wasteful spending';
        break;
      case FinancialGoal.other:
        description = 'Other financial goals not listed here';
        break;
    }

    return Text(
      description,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
    );
  }

  Widget _buildIncomeRangePage() {
    return Consumer<UserPreferencesProvider>(builder: (context, provider, _) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What\'s your annual income range?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'This helps us suggest appropriate budgeting strategies.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your data is only used to personalize the app. We never share it.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ...IncomeRange.values
                        .map((range) => _buildIncomeOption(range)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildIncomeOption(IncomeRange range) {
    return Consumer<UserPreferencesProvider>(builder: (context, provider, _) {
      final isSelected = provider.tempIncomeRange == range;

      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: isSelected ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            provider.setTempIncomeRange(range);
            _updateCanContinue();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    UserPreferences.incomeRangeToString(range),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Radio(
                  value: range,
                  groupValue: provider.tempIncomeRange,
                  onChanged: (IncomeRange? value) {
                    if (value != null) {
                      provider.setTempIncomeRange(value);
                      _updateCanContinue();
                    }
                  },
                  activeColor: AppTheme.primaryGreen,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildExpertisePage() {
    return Consumer<UserPreferencesProvider>(builder: (context, provider, _) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How would you rate your financial knowledge?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'We\'ll adjust the level of guidance and explanations accordingly.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                  ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ...FinancialExpertise.values
                        .map((expertise) => _buildExpertiseOption(expertise)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildExpertiseOption(FinancialExpertise expertise) {
    return Consumer<UserPreferencesProvider>(builder: (context, provider, _) {
      final isSelected = provider.tempExpertise == expertise;

      IconData iconData;
      String description;

      switch (expertise) {
        case FinancialExpertise.beginner:
          iconData = Icons.school_outlined;
          description = 'I\'m new to personal finance and could use guidance';
          break;
        case FinancialExpertise.intermediate:
          iconData = Icons.trending_up;
          description = 'I understand the basics but want to improve my skills';
          break;
        case FinancialExpertise.advanced:
          iconData = Icons.analytics_outlined;
          description =
              'I\'m experienced with budgeting, investing, and financial planning';
          break;
      }

      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: isSelected ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: () {
            provider.setTempExpertise(expertise);
            _updateCanContinue();
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryGreen.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    iconData,
                    color: isSelected ? AppTheme.primaryGreen : Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        UserPreferences.expertiseToString(expertise),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
                Radio(
                  value: expertise,
                  groupValue: provider.tempExpertise,
                  onChanged: (FinancialExpertise? value) {
                    if (value != null) {
                      provider.setTempExpertise(value);
                      _updateCanContinue();
                    }
                  },
                  activeColor: AppTheme.primaryGreen,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildAdditionalPreferencesPage() {
    final provider = Provider.of<UserPreferencesProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional preferences',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Just a few more questions to further personalize your experience.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildSwitchOption(
                    title: 'I already have a budget',
                    subtitle:
                        'Enable to import or build on your existing budget',
                    value: provider.tempHasExistingBudget,
                    onChanged: (value) {
                      provider.setTempHasExistingBudget(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildSwitchOption(
                    title: 'I\'m interested in investing',
                    subtitle:
                        'We\'ll show investment tracking features and tips',
                    value: provider.tempInterestedInInvesting,
                    onChanged: (value) {
                      provider.setTempInterestedInInvesting(value);
                    },
                  ),
                  const SizedBox(height: 24),
                  if (provider.tempPrimaryGoal != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Secondary financial goals (optional)',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 16),
                        ...FinancialGoal.values
                            .where((goal) => goal != provider.tempPrimaryGoal)
                            .map((goal) => _buildSecondaryGoalOption(goal)),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchOption({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.primaryGreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryGoalOption(FinancialGoal goal) {
    final provider = Provider.of<UserPreferencesProvider>(context);
    final isSelected = provider.tempSecondaryGoals.contains(goal);

    return CheckboxListTile(
      title: Text(
        UserPreferences.financialGoalToString(goal),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      value: isSelected,
      onChanged: (bool? value) {
        if (value != null) {
          provider.toggleTempSecondaryGoal(goal);
        }
      },
      activeColor: AppTheme.primaryGreen,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }

  Widget _buildBottomButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _canContinue ? _nextPage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              disabledBackgroundColor: Colors.grey[300],
            ),
            child: Text(
              _currentPage < _totalPages - 1 ? 'Continue' : 'Finish',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  void _updateCanContinue() {
    final provider =
        Provider.of<UserPreferencesProvider>(context, listen: false);

    setState(() {
      switch (_currentPage) {
        case 0:
          _canContinue = provider.tempPrimaryGoal != null;
          break;
        case 1:
          _canContinue = provider.tempIncomeRange != null;
          break;
        case 2:
          _canContinue = provider.tempExpertise != null;
          break;
        case 3:
          // Always allow continuation on the last page
          _canContinue = true;
          break;
        default:
          _canContinue = false;
      }
    });
  }
}
