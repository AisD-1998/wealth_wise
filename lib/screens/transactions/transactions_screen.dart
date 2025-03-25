import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:wealth_wise/models/transaction.dart' as app_model;
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/utils/ui_helpers.dart';
import 'package:wealth_wise/providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  app_model.TransactionType? _filterType;
  bool _isLoading = false;
  String _debugInfo = "";
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
        _debugInfo = "Loading transactions...";
      });
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final financeProvider =
          Provider.of<FinanceProvider>(context, listen: false);

      _logger.info('Loading transactions...');

      if (authProvider.user != null) {
        String userId = authProvider.user!.uid;
        _debugInfo += "\nUser ID: $userId";
        _logger.info('User ID: $userId');

        // Force a complete reload of the data
        await financeProvider.initializeFinanceData(userId);

        // Get transaction count for debugging
        int count = financeProvider.transactions.length;
        _debugInfo += "\nTransactions loaded via provider: $count";
        _logger.info('Transactions loaded via provider: $count');

        // Direct Firestore query for debugging
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection('transactions')
              .where('userId', isEqualTo: userId)
              .get();

          _debugInfo +=
              "\nDirect Firestore query count: ${snapshot.docs.length}";
          _logger.info('Direct Firestore query count: ${snapshot.docs.length}');

          // Log details about first document if available
          if (snapshot.docs.isNotEmpty) {
            var firstDoc = snapshot.docs.first.data();
            _debugInfo +=
                "\nFirst document: ${firstDoc.toString().substring(0, firstDoc.toString().length > 100 ? 100 : firstDoc.toString().length)}...";
            _logger.info('First document found');
          }
        } catch (firestoreError) {
          _debugInfo += "\nFirestore direct query error: $firestoreError";
          _logger.warning('Firestore direct query error: $firestoreError');
        }
      } else {
        _debugInfo += "\nNo authenticated user found";
        _logger.warning('No authenticated user found');
      }
    } catch (e) {
      _debugInfo += "\nError loading transactions: $e";
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Show filter options
              _showFilterOptions(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Show search bar (future implementation)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Search will be available in future updates')),
              );
            },
          ),
          // Add refresh button explicitly
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
          ),
          // Add repair data button
          IconButton(
            icon: const Icon(Icons.healing),
            tooltip: 'Repair data',
            onPressed: () async {
              // Store context before async operation
              final scaffoldContext = ScaffoldMessenger.of(context);
              final navigatorContext = Navigator.of(context);
              final financeProvider =
                  Provider.of<FinanceProvider>(context, listen: false);

              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext) => const AlertDialog(
                  title: Text('Repairing Data'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Fixing database issues...'),
                    ],
                  ),
                ),
              );

              try {
                // Load user finances instead of running migrations
                final userId = context.read<AuthProvider>().user?.uid;
                if (userId == null) {
                  throw Exception('User not authenticated');
                }
                await financeProvider.loadUserFinances(userId);

                // Close the dialog - don't use context from closure
                if (mounted && navigatorContext.canPop()) {
                  navigatorContext.pop();
                }

                // Reload transactions
                await _loadTransactions();

                // Show success message
                if (mounted) {
                  scaffoldContext.showSnackBar(
                    const SnackBar(
                      content: Text('Data loaded successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                // Close the dialog - don't use context from closure
                if (mounted && navigatorContext.canPop()) {
                  navigatorContext.pop();
                }

                // Show error message
                if (mounted) {
                  scaffoldContext.showSnackBar(
                    SnackBar(
                      content: Text('Error loading data: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          // Add debug info button
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Debug Info'),
                  content: SingleChildScrollView(
                    child: SelectableText(_debugInfo),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : filteredTransactions.isEmpty
                ? Center(
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
                  )
                : _buildTransactionsList(filteredTransactions),
      ),
    );
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
                leading: Icon(
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
                leading: Icon(
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
      final date = DateFormat('yyyy-MM-dd').format(transaction.date);

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

    if (DateFormat('yyyy-MM-dd').format(now) == dateStr) {
      return 'Today';
    } else if (DateFormat('yyyy-MM-dd').format(yesterday) == dateStr) {
      return 'Yesterday';
    } else {
      return DateFormat('MMMM d, yyyy').format(date);
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

class TransactionListItem extends StatelessWidget {
  final app_model.Transaction transaction;

  const TransactionListItem({
    super.key,
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == app_model.TransactionType.income;
    final formattedAmount = isIncome
        ? '+\$${transaction.amount.toStringAsFixed(2)}'
        : '-\$${transaction.amount.toStringAsFixed(2)}';

    // Determine icon based on category
    IconData iconData;
    Color iconColor;

    if (isIncome) {
      iconData = Icons.arrow_upward;
      iconColor = Colors.green;
    } else {
      switch (transaction.category) {
        case 'Food & Groceries':
          iconData = Icons.shopping_cart;
          iconColor = Colors.green;
          break;
        case 'Transportation':
          iconData = Icons.directions_car;
          iconColor = Colors.blue;
          break;
        case 'Entertainment':
          iconData = Icons.movie;
          iconColor = Colors.purple;
          break;
        case 'Utilities':
          iconData = Icons.lightbulb;
          iconColor = Colors.amber;
          break;
        case 'Housing':
          iconData = Icons.home;
          iconColor = Colors.brown;
          break;
        case 'Health':
          iconData = Icons.medical_services;
          iconColor = Colors.red;
          break;
        case 'Savings':
          iconData = Icons.savings;
          iconColor = Colors.teal;
          break;
        default:
          iconData = Icons.arrow_downward;
          iconColor = Colors.red;
      }
    }

    return Dismissible(
      key: Key(transaction.id ?? DateTime.now().toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        return await UIHelpers.showConfirmationDialog(
          context: context,
          title: 'Delete Transaction',
          message: 'Are you sure you want to delete this transaction?',
          confirmText: 'Delete',
          cancelText: 'Cancel',
        );
      },
      onDismissed: (direction) async {
        final financeProvider =
            Provider.of<FinanceProvider>(context, listen: false);
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final scaffoldMessenger = ScaffoldMessenger.of(context);

        try {
          if (transaction.id != null) {
            final success =
                await financeProvider.deleteTransaction(transaction);

            if (success) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: const Text('Transaction deleted'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      // Re-add the transaction if user wants to undo
                      financeProvider.addTransaction(transaction);
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
                    content: Text(financeProvider.error ??
                        'Failed to delete transaction')),
              );

              // Refresh the list
              if (context.mounted && authProvider.user?.uid != null) {
                await financeProvider
                    .initializeFinanceData(authProvider.user!.uid);
              }
            }
          }
        } catch (e) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      },
      child: InkWell(
        onLongPress: () {
          _showTransactionOptions(context, transaction);
        },
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: iconColor.withValues(alpha: 51),
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          title: Text(transaction.title),
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
                DateFormat('h:mm a').format(transaction.date),
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
        ),
      ),
    );
  }

  void _showTransactionOptions(
      BuildContext context, app_model.Transaction transaction) {
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
                  Navigator.pop(context);
                  UIHelpers.showTransactionForm(
                    context,
                    transaction.type,
                    existingTransaction: transaction,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Transaction',
                    style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await UIHelpers.showConfirmationDialog(
                    context: context,
                    title: 'Delete Transaction',
                    message:
                        'Are you sure you want to delete this transaction?',
                    confirmText: 'Delete',
                    cancelText: 'Cancel',
                  );

                  if (confirm && context.mounted) {
                    final financeProvider =
                        Provider.of<FinanceProvider>(context, listen: false);
                    try {
                      await financeProvider.deleteTransaction(transaction);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
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

  void _showTransactionDetails(
      BuildContext context, app_model.Transaction transaction) {
    final theme = Theme.of(context);
    final isIncome = transaction.type == app_model.TransactionType.income;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title and amount row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      transaction.title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    isIncome
                        ? '+\$${transaction.amount.toStringAsFixed(2)}'
                        : '-\$${transaction.amount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: isIncome ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Details list
              DetailItem(
                icon: Icons.calendar_today,
                title: 'Date',
                value: DateFormat('MMMM d, yyyy').format(transaction.date),
              ),
              DetailItem(
                icon: Icons.access_time,
                title: 'Time',
                value: DateFormat('h:mm a').format(transaction.date),
              ),
              DetailItem(
                icon: Icons.category,
                title: 'Category',
                value: transaction.category ?? 'Uncategorized',
              ),
              if (transaction.note != null && transaction.note!.isNotEmpty)
                DetailItem(
                  icon: Icons.notes,
                  title: 'Notes',
                  value: transaction.note!,
                ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                    onPressed: () {
                      Navigator.pop(context);
                      UIHelpers.showTransactionForm(
                        context,
                        transaction.type,
                        existingTransaction: transaction,
                      );
                    },
                  ),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                    onPressed: () async {
                      Navigator.pop(context);
                      final confirm = await UIHelpers.showConfirmationDialog(
                        context: context,
                        title: 'Delete Transaction',
                        message:
                            'Are you sure you want to delete this transaction?',
                        confirmText: 'Delete',
                        cancelText: 'Cancel',
                      );

                      if (confirm && context.mounted) {
                        final financeProvider = Provider.of<FinanceProvider>(
                            context,
                            listen: false);
                        try {
                          await financeProvider.deleteTransaction(transaction);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
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
