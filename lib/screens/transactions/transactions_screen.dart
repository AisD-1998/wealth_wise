import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:wealth_wise/models/transaction.dart' as app_model;
import 'package:wealth_wise/models/saving_goal.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/utils/ui_helpers.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';
import 'package:wealth_wise/widgets/loading_animation_utils.dart';
import 'package:wealth_wise/widgets/loading_indicator.dart';
import 'package:wealth_wise/utils/currency_formatter.dart';
import 'package:wealth_wise/constants/app_strings.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  app_model.TransactionType? _filterType;
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isSearching = false;
  final Logger _logger = Logger('TransactionsScreen');

  @override
  void initState() {
    super.initState();
    // Load transactions when screen initializes
    _loadTransactions();
  }

  // Load transactions from database
  Future<void> _loadTransactions() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final financeProvider =
          Provider.of<FinanceProvider>(context, listen: false);

      _logger.info('Loading transactions...');

      if (authProvider.user != null) {
        String userId = authProvider.user!.uid;
        _logger.info('User ID: $userId');

        // Force a complete reload of the data
        await financeProvider.initializeFinanceData(userId);

        // Get transaction count for debugging
        int count = financeProvider.transactions.length;
        _logger.info('Transactions loaded via provider: $count');

        // Direct Firestore query for debugging
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('transactions')
              .where('userId', isEqualTo: userId)
              .get();

          _logger.info('Direct Firestore query count: ${snapshot.docs.length}');

          // Log details about first document if available
          if (snapshot.docs.isNotEmpty) {
            _logger.info('First document found');
          }
        } catch (firestoreError) {
          _logger.warning('Firestore direct query error: $firestoreError');
        }
      } else {
        _logger.warning('No authenticated user found');
      }
    } catch (e) {
      _logger.severe('Error loading transactions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context);
    List<app_model.Transaction> filteredTransactions =
        financeProvider.transactions;

    // Apply filters if selected
    if (_filterType != null) {
      filteredTransactions = filteredTransactions
          .where((transaction) => transaction.type == _filterType)
          .toList();
    }

    // Apply search filter if searching
    if (_isSearching && _searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredTransactions = filteredTransactions.where((transaction) {
        final titleMatch = transaction.title.toLowerCase().contains(query);
        final categoryMatch =
            transaction.category?.toLowerCase().contains(query) ?? false;
        final noteMatch =
            transaction.note?.toLowerCase().contains(query) ?? false;
        return titleMatch || categoryMatch || noteMatch;
      }).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search transactions...',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              )
            : const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Show filter options
              _showFilterOptions(context);
            },
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchQuery = '';
                }
              });
            },
          ),
          // Add refresh button explicitly
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: _buildTransactionsBody(context, filteredTransactions),
      ),
    );
  }

  Widget _buildTransactionsBody(
      BuildContext context,
      List<app_model.Transaction> filteredTransactions) {
    if (_isLoading) {
      return const Center(
        child: LoadingIndicator(
            size: 50, message: 'Loading transactions...'),
      );
    }
    if (filteredTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Transactions will appear here',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    return _buildTransactionsList(filteredTransactions);
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filter Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.all_inclusive),
                title: const Text('All Transactions'),
                onTap: () {
                  setState(() {
                    _filterType = null;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.arrow_upward,
                  color: Colors.green,
                ),
                title: const Text('Income Only'),
                onTap: () {
                  setState(() {
                    _filterType = app_model.TransactionType.income;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.arrow_downward,
                  color: Colors.red,
                ),
                title: const Text('Expenses Only'),
                onTap: () {
                  setState(() {
                    _filterType = app_model.TransactionType.expense;
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTransactionsList(List<app_model.Transaction> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your transactions will appear here',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Transaction'),
              onPressed: () {
                UIHelpers.showTransactionForm(
                    context, app_model.TransactionType.expense);
              },
            ),
          ],
        ),
      );
    }

    // Group transactions by date
    final groupedTransactions = <String, List<app_model.Transaction>>{};

    for (final transaction in transactions) {
      final date = DateFormat(AppStrings.kDateFormatShort).format(transaction.date);

      if (!groupedTransactions.containsKey(date)) {
        groupedTransactions[date] = [];
      }

      groupedTransactions[date]!.add(transaction);
    }

    // Sort dates in descending order (newest first)
    final sortedDates = groupedTransactions.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      children: [
        // Filter chips for transaction types
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  selected: _filterType == null,
                  label: const Text('All'),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _filterType = null;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _filterType == app_model.TransactionType.income,
                  label: const Text('Income'),
                  onSelected: (selected) {
                    setState(() {
                      _filterType =
                          selected ? app_model.TransactionType.income : null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: _filterType == app_model.TransactionType.expense,
                  label: const Text('Expense'),
                  onSelected: (selected) {
                    setState(() {
                      _filterType =
                          selected ? app_model.TransactionType.expense : null;
                    });
                  },
                ),
              ],
            ),
          ),
        ),

        // Display grouped transactions
        for (final date in sortedDates)
          TransactionGroup(
            title: _formatGroupDate(date),
            transactions: groupedTransactions[date]!,
          ),
      ],
    );
  }

  String _formatGroupDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    if (DateFormat(AppStrings.kDateFormatShort).format(now) == dateStr) {
      return 'Today';
    } else if (DateFormat(AppStrings.kDateFormatShort).format(yesterday) == dateStr) {
      return 'Yesterday';
    } else {
      return DateFormat(AppStrings.kDateFormatLong).format(date);
    }
  }
}

class TransactionGroup extends StatelessWidget {
  final String title;
  final List<app_model.Transaction> transactions;

  const TransactionGroup({
    super.key,
    required this.title,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...transactions.map(
            (transaction) => TransactionListItem(transaction: transaction)),
      ],
    );
  }
}

class TransactionListItem extends StatefulWidget {
  final app_model.Transaction transaction;

  const TransactionListItem({
    super.key,
    required this.transaction,
  });

  @override
  State<TransactionListItem> createState() => _TransactionListItemState();
}

class _TransactionListItemState extends State<TransactionListItem> {
  /// Returns the appropriate icon and color based on the transaction type and category.
  (IconData, Color) _getCategoryIconAndColor(app_model.Transaction transaction) {
    final isIncome = transaction.type == app_model.TransactionType.income;

    if (isIncome) {
      return (Icons.arrow_upward, Colors.green);
    }

    switch (transaction.category) {
      case 'Food & Groceries':
        return (Icons.shopping_cart, Colors.green);
      case 'Transportation':
        return (Icons.directions_car, Colors.blue);
      case 'Entertainment':
        return (Icons.movie, Colors.purple);
      case 'Utilities':
        return (Icons.lightbulb, Colors.amber);
      case 'Housing':
        return (Icons.home, Colors.brown);
      case 'Health':
        return (Icons.medical_services, Colors.red);
      case 'Savings':
        return (Icons.savings, Colors.teal);
      default:
        return (Icons.arrow_downward, Colors.red);
    }
  }

  /// Builds the red delete background shown when swiping to dismiss.
  Widget _buildDismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20.0),
      color: Colors.red,
      child: const Icon(
        Icons.delete,
        color: Colors.white,
      ),
    );
  }

  /// Shows the delete confirmation dialog. Returns true if user confirms.
  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(AppStrings.kDeleteTransaction),
          content: Text(AppStrings.kDeleteConfirmation),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              child:
                  const Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Handles the async delete operation with undo snackbar logic.
  Future<void> _handleDeleteTransaction({
    required app_model.Transaction transaction,
    required FinanceProvider financeProvider,
    required AuthProvider authProvider,
    required ScaffoldMessengerState scaffoldMessenger,
  }) async {
    try {
      if (transaction.id != null) {
        // Show loading indicator
        scaffoldMessenger.showSnackBar(
          LoadingAnimationUtils.loadingSnackBar(AppStrings.kDeletingTransaction),
        );

        final success =
            await financeProvider.deleteTransaction(transaction);

        if (success) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(AppStrings.kTransactionDeleted),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  // Re-add the transaction if user wants to undo
                  await financeProvider.addTransaction(transaction);

                  // Refresh data
                  if (authProvider.user?.uid != null) {
                    await financeProvider
                        .initializeFinanceData(authProvider.user!.uid);
                  }
                },
              ),
            ),
          );

          // Refresh the full data to ensure UI is updated
          if (authProvider.user?.uid != null) {
            await financeProvider
                .initializeFinanceData(authProvider.user!.uid);
          }
        } else {
          // If deletion fails, show error and force a refresh
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                  financeProvider.error ?? AppStrings.kDeleteFailed),
              backgroundColor: Colors.red,
            ),
          );

          // Refresh the list
          if (authProvider.user?.uid != null) {
            await financeProvider
                .initializeFinanceData(authProvider.user!.uid);
          }
        }
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Builds the ListTile for the transaction item.
  Widget _buildTransactionTile({
    required app_model.Transaction transaction,
    required bool isIncome,
    required String formattedAmount,
    required IconData iconData,
    required Color iconColor,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 51),
        child: Icon(iconData, color: iconColor, size: 20),
      ),
      title: Row(
        children: [
          Flexible(child: Text(transaction.title)),
          if (transaction.isRecurring) ...[
            const SizedBox(width: 4),
            Icon(
              transaction.isPaused ? Icons.pause_circle_outline : Icons.repeat,
              size: 16,
              color: transaction.isPaused ? Colors.orange : Colors.grey,
            ),
          ],
        ],
      ),
      subtitle: Text(transaction.category ?? 'Uncategorized'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formattedAmount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
          Text(
            DateFormat(AppStrings.kTimeFormat).format(transaction.date),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      onTap: () {
        _showTransactionDetails(context, transaction);
      },
    );
  }

  /// Builds a detail row with a label and value, used in transaction detail bottom sheets.
  Widget _buildDetailRow(BuildContext context, String label, String value, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          value,
          style: valueStyle,
        ),
      ],
    );
  }

  /// Builds the goal info section with a FutureBuilder for the saving goal.
  Widget _buildGoalInfoSection(
    BuildContext context,
    app_model.Transaction transaction,
    FinanceProvider financeProvider,
  ) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Saving Goal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        if (transaction.goalId != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: FutureBuilder<SavingGoal?>(
              future: financeProvider
                  .getSavingGoalById(transaction.goalId!),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: LoadingAnimationUtils
                            .smallDollarSpinner(size: 20)),
                  );
                }

                final goal = snapshot.data;
                if (goal == null) {
                  return const Text('Goal not found',
                      style: TextStyle(
                          fontStyle: FontStyle.italic));
                }

                return Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 77),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: HexColor.fromHex(
                            goal.colorCode ?? '#3C63F9'),
                        radius: 16,
                        child: Icon(
                          UIHelpers.getIconForGoalTitle(
                              goal.title),
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${CurrencyFormatter.formatWithContext(context, goal.currentAmount)} of ${CurrencyFormatter.formatWithContext(context, goal.targetAmount)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall,
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: goal.progressPercentage /
                                    100,
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// Builds the Edit/Delete action buttons for the transaction detail bottom sheet.
  Widget _buildActionButtons(
    BuildContext context,
    app_model.Transaction transaction,
    FinanceProvider financeProvider,
    AuthProvider authProvider,
    ScaffoldMessengerState scaffoldMessenger,
  ) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Edit'),
              onPressed: () {
                // Get a reference to these before closing modal
                final transactionToEdit = transaction;
                final currentContext = context;

                // Close the modal
                Navigator.pop(context);

                // Show edit form using a more reliable approach
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  UIHelpers.showTransactionForm(
                    currentContext,
                    transactionToEdit.type,
                    existingTransaction: transactionToEdit,
                  );
                });
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete, color: Colors.red),
              label: const Text('Delete',
                  style: TextStyle(color: Colors.red)),
              onPressed: () async {
                // Close the modal first
                Navigator.pop(context);

                final confirm = await _confirmDelete(context);

                if (confirm) {
                  // Show loading indicator
                  scaffoldMessenger.showSnackBar(
                    LoadingAnimationUtils.loadingSnackBar(
                        AppStrings.kDeletingTransaction),
                  );

                  try {
                    final success = await financeProvider
                        .deleteTransaction(transaction);

                    if (success) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(AppStrings.kTransactionDeleted),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () async {
                              await financeProvider
                                  .addTransaction(transaction);
                              if (authProvider.user?.uid !=
                                  null) {
                                await financeProvider
                                    .initializeFinanceData(
                                        authProvider.user!.uid);
                              }
                            },
                          ),
                        ),
                      );

                      // Refresh the data
                      if (authProvider.user?.uid != null) {
                        await financeProvider
                            .initializeFinanceData(
                                authProvider.user!.uid);
                      }
                    } else {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(financeProvider.error ??
                              AppStrings.kDeleteFailed),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } catch (e) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  /// Shows a bottom sheet with full transaction details.
  void _showTransactionDetails(BuildContext context, app_model.Transaction transaction) {
    final financeProvider =
        Provider.of<FinanceProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final isIncome =
        transaction.type == app_model.TransactionType.income;
    final formattedAmount = isIncome
        ? '+${CurrencyFormatter.formatWithContext(context, transaction.amount)}'
        : '-${CurrencyFormatter.formatWithContext(context, transaction.amount)}';

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                transaction.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                transaction.category ?? 'Uncategorized',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 16),
              _buildDetailRow(
                context,
                'Amount',
                formattedAmount,
                valueStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isIncome ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              _buildDetailRow(
                context,
                'Date',
                DateFormat(AppStrings.kDateFormatLong).format(transaction.date),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                context,
                'Time',
                DateFormat(AppStrings.kTimeFormat).format(transaction.date),
              ),
              if (transaction.note != null &&
                  transaction.note!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Notes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(transaction.note!),
              ],
              if (transaction.type ==
                      app_model.TransactionType.expense ||
                  transaction.type ==
                      app_model.TransactionType.income)
                _buildGoalInfoSection(context, transaction, financeProvider),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Center(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.check),
                  label: const Text('Close'),
                ),
              ),
              // Add action buttons for edit and delete
              _buildActionButtons(
                context,
                transaction,
                financeProvider,
                authProvider,
                scaffoldMessenger,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final transaction = widget.transaction;
    final isIncome = transaction.type == app_model.TransactionType.income;
    final formattedAmount = isIncome
        ? '+${CurrencyFormatter.formatWithContext(context, transaction.amount)}'
        : '-${CurrencyFormatter.formatWithContext(context, transaction.amount)}';

    // Get providers early to avoid deactivated context issues
    final financeProvider =
        Provider.of<FinanceProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Determine icon based on category
    final (iconData, iconColor) = _getCategoryIconAndColor(transaction);

    return Dismissible(
      key: Key(transaction.id ?? DateTime.now().toString()),
      direction: DismissDirection.endToStart,
      background: _buildDismissBackground(),
      confirmDismiss: (direction) async {
        return _confirmDelete(context);
      },
      onDismissed: (direction) async {
        await _handleDeleteTransaction(
          transaction: transaction,
          financeProvider: financeProvider,
          authProvider: authProvider,
          scaffoldMessenger: scaffoldMessenger,
        );
      },
      child: InkWell(
        onLongPress: () {
          _showTransactionOptions(context, transaction);
        },
        child: _buildTransactionTile(
          transaction: transaction,
          isIncome: isIncome,
          formattedAmount: formattedAmount,
          iconData: iconData,
          iconColor: iconColor,
        ),
      ),
    );
  }

  void _showTransactionOptions(
      BuildContext context, app_model.Transaction transaction) {
    // Get providers early to avoid deactivated context issues
    final financeProvider =
        Provider.of<FinanceProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('View Details'),
                onTap: () {
                  Navigator.pop(context);
                  _showTransactionDetails(context, transaction);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Transaction'),
                onTap: () {
                  // Get a reference to these before closing modal
                  final transactionToEdit = transaction;
                  final currentContext = context;

                  // Close the modal
                  Navigator.pop(context);

                  // Show edit form using a more reliable approach
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    UIHelpers.showTransactionForm(
                      currentContext,
                      transactionToEdit.type,
                      existingTransaction: transactionToEdit,
                    );
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(AppStrings.kDeleteTransaction,
                    style: const TextStyle(color: Colors.red)),
                onTap: () async {
                  // Close the modal first
                  Navigator.pop(context);

                  final confirm = await _confirmDelete(context);

                  if (confirm) {
                    // Show loading indicator
                    scaffoldMessenger.showSnackBar(
                      LoadingAnimationUtils.loadingSnackBar(
                          AppStrings.kDeletingTransaction),
                    );

                    try {
                      final success =
                          await financeProvider.deleteTransaction(transaction);

                      if (success) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(AppStrings.kTransactionDeleted),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () async {
                                await financeProvider
                                    .addTransaction(transaction);
                                if (authProvider.user?.uid != null) {
                                  await financeProvider.initializeFinanceData(
                                      authProvider.user!.uid);
                                }
                              },
                            ),
                          ),
                        );

                        // Refresh the data
                        if (authProvider.user?.uid != null) {
                          await financeProvider
                              .initializeFinanceData(authProvider.user!.uid);
                        }
                      } else {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(financeProvider.error ??
                                AppStrings.kDeleteFailed),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class DetailItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const DetailItem({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
