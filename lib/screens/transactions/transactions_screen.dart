import 'package:flutter/material.dart';
import 'package:wealth_wise/screens/transactions/add_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Show filter options
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Show search bar
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // Filter chips for transaction types
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    selected: true,
                    label: Text('All'),
                    onSelected: null,
                  ),
                  SizedBox(width: 8),
                  FilterChip(
                    selected: false,
                    label: Text('Income'),
                    onSelected: null,
                  ),
                  SizedBox(width: 8),
                  FilterChip(
                    selected: false,
                    label: Text('Expense'),
                    onSelected: null,
                  ),
                  SizedBox(width: 8),
                  FilterChip(
                    selected: false,
                    label: Text('Transfer'),
                    onSelected: null,
                  ),
                ],
              ),
            ),
          ),

          // Sample transactions
          const TransactionGroup(
            title: 'Today',
            transactions: [
              TransactionListItem(
                title: 'Grocery Store',
                category: 'Food & Groceries',
                amount: -54.35,
                date: 'Today, 2:30 PM',
                iconData: Icons.shopping_cart,
                iconColor: Colors.green,
              ),
              TransactionListItem(
                title: 'Coffee Shop',
                category: 'Food & Drinks',
                amount: -4.50,
                date: 'Today, 9:15 AM',
                iconData: Icons.coffee,
                iconColor: Colors.brown,
              ),
            ],
          ),

          const TransactionGroup(
            title: 'Yesterday',
            transactions: [
              TransactionListItem(
                title: 'Netflix Subscription',
                category: 'Entertainment',
                amount: -14.99,
                date: 'Yesterday, 3:00 PM',
                iconData: Icons.movie,
                iconColor: Colors.red,
              ),
              TransactionListItem(
                title: 'Gas Station',
                category: 'Transportation',
                amount: -45.75,
                date: 'Yesterday, 10:30 AM',
                iconData: Icons.local_gas_station,
                iconColor: Colors.orange,
              ),
            ],
          ),

          const TransactionGroup(
            title: 'March 20, 2025',
            transactions: [
              TransactionListItem(
                title: 'Monthly Salary',
                category: 'Income',
                amount: 2850.00,
                date: 'Mar 20, 8:00 AM',
                iconData: Icons.work,
                iconColor: Colors.blue,
              ),
              TransactionListItem(
                title: 'Electric Bill',
                category: 'Utilities',
                amount: -125.40,
                date: 'Mar 20, 9:30 AM',
                iconData: Icons.electric_bolt,
                iconColor: Colors.yellow,
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class TransactionGroup extends StatelessWidget {
  final String title;
  final List<TransactionListItem> transactions;

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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...transactions,
      ],
    );
  }
}

class TransactionListItem extends StatelessWidget {
  final String title;
  final String category;
  final double amount;
  final String date;
  final IconData iconData;
  final Color iconColor;

  const TransactionListItem({
    super.key,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    required this.iconData,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = amount > 0;
    final formattedAmount = isIncome
        ? '+\$${amount.toStringAsFixed(2)}'
        : '-\$${amount.abs().toStringAsFixed(2)}';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withAlpha(50),
        child: Icon(iconData, color: iconColor, size: 20),
      ),
      title: Text(title),
      subtitle: Text(category),
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
            date,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      onTap: () {
        // Show transaction details
      },
    );
  }
}
