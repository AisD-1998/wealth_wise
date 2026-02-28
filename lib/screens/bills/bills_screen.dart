import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wealth_wise/models/bill_reminder.dart';
import 'package:wealth_wise/providers/finance_provider.dart';
import 'package:wealth_wise/screens/bills/create_bill_screen.dart';
import 'package:wealth_wise/utils/currency_formatter.dart';

class BillsScreen extends StatelessWidget {
  const BillsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Reminders'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateBillScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: Consumer<FinanceProvider>(
        builder: (context, provider, _) {
          final bills = provider.billReminders;

          if (bills.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No bill reminders yet',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add recurring bills to stay on top of payments',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          // Separate overdue, upcoming, and paid
          final overdue = bills.where((b) => b.isOverdue).toList()
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
          final upcoming =
              bills.where((b) => !b.isPaid && !b.isOverdue).toList()
                ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
          final paid = bills.where((b) => b.isPaid).toList()
            ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (overdue.isNotEmpty) ...[
                _sectionHeader(context, 'Overdue', Colors.red),
                ...overdue
                    .map((b) => _buildBillCard(context, b, provider)),
                const SizedBox(height: 16),
              ],
              if (upcoming.isNotEmpty) ...[
                _sectionHeader(context, 'Upcoming', theme.colorScheme.primary),
                ...upcoming
                    .map((b) => _buildBillCard(context, b, provider)),
                const SizedBox(height: 16),
              ],
              if (paid.isNotEmpty) ...[
                _sectionHeader(context, 'Paid', Colors.green),
                ...paid
                    .take(10)
                    .map((b) => _buildBillCard(context, b, provider)),
              ],
            ],
          );
        },
      ),
    );
  }

  IconData _billIcon(BillReminder bill) {
    if (bill.isPaid) return Icons.check_circle;
    if (bill.isOverdue) return Icons.warning_amber_rounded;
    return Icons.receipt_long;
  }

  Widget _sectionHeader(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillCard(
    BuildContext context,
    BillReminder bill,
    FinanceProvider provider,
  ) {
    final theme = Theme.of(context);
    final daysUntil = bill.daysUntilDue;

    Color statusColor;
    String statusText;
    if (bill.isPaid) {
      statusColor = Colors.green;
      statusText = 'Paid';
    } else if (bill.isOverdue) {
      statusColor = Colors.red;
      statusText = '${daysUntil.abs()} days overdue';
    } else if (daysUntil == 0) {
      statusColor = Colors.orange;
      statusText = 'Due today';
    } else if (daysUntil <= 3) {
      statusColor = Colors.orange;
      statusText = 'Due in $daysUntil days';
    } else {
      statusColor = Colors.grey;
      statusText = 'Due ${DateFormat('MMM dd').format(bill.dueDate)}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 30),
          child: Icon(
            _billIcon(bill),
            color: statusColor,
            size: 22,
          ),
        ),
        title: Text(
          bill.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: bill.isPaid ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(
          children: [
            Text(
              statusText,
              style: TextStyle(color: statusColor, fontSize: 12),
            ),
            const SizedBox(width: 8),
            Text(
              bill.recurrence.label,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.formatWithContext(context, bill.amount),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!bill.isPaid)
              PopupMenuButton<String>(
                onSelected: (value) =>
                    _handleMenuAction(context, value, bill, provider),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'pay',
                    child: ListTile(
                      leading: Icon(Icons.check_circle_outline),
                      title: Text('Mark as Paid'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'pay_expense',
                    child: ListTile(
                      leading: Icon(Icons.receipt),
                      title: Text('Pay & Log Expense'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Edit'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title:
                          Text('Delete', style: TextStyle(color: Colors.red)),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => CreateBillScreen(existingBill: bill)),
          );
        },
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action,
      BillReminder bill, FinanceProvider provider) async {
    switch (action) {
      case 'pay':
        _handlePayAction(context, bill, provider);
        break;
      case 'pay_expense':
        _handlePayExpenseAction(context, bill, provider);
        break;
      case 'edit':
        _handleEditAction(context, bill);
        break;
      case 'delete':
        _handleDeleteAction(context, bill, provider);
        break;
    }
  }

  void _handlePayAction(BuildContext context, BillReminder bill,
      FinanceProvider provider) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final success = await provider.markBillPaid(bill);
    scaffoldMessenger.showSnackBar(SnackBar(
      content: Text(success
          ? '${bill.title} marked as paid'
          : 'Failed to mark as paid'),
      backgroundColor: success ? Colors.green : Colors.red,
    ));
  }

  void _handlePayExpenseAction(BuildContext context, BillReminder bill,
      FinanceProvider provider) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final success =
        await provider.markBillPaid(bill, createTransaction: true);
    scaffoldMessenger.showSnackBar(SnackBar(
      content: Text(success
          ? '${bill.title} paid & expense logged'
          : 'Failed to process payment'),
      backgroundColor: success ? Colors.green : Colors.red,
    ));
  }

  void _handleEditAction(BuildContext context, BillReminder bill) {
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => CreateBillScreen(existingBill: bill)),
      );
    }
  }

  void _handleDeleteAction(BuildContext context, BillReminder bill,
      FinanceProvider provider) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bill Reminder'),
        content: Text('Delete "${bill.title}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && bill.id != null) {
      final success = await provider.deleteBillReminder(bill.id!);
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text(success
            ? '${bill.title} deleted'
            : 'Failed to delete'),
        backgroundColor: success ? Colors.green : Colors.red,
      ));
    }
  }
}
